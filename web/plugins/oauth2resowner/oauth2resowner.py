import urllib
import copy
import os
from time import time


from oauthlib.oauth2 import LegacyApplicationServer, RequestValidator
from qgis.server import QgsServerFilter
from qgis.core import QgsMessageLog

QGIS_SERVER_OAUTH2_USERNAME = os.environ.get(
    'QGIS_SERVER_OAUTH2_USERNAME', 'username')
QGIS_SERVER_OAUTH2_PASSWORD = os.environ.get(
    'QGIS_SERVER_OAUTH2_PASSWORD', 'password')
QGIS_SERVER_OAUTH2_TOKEN_EXPIRES_IN = os.environ.get(
    'QGIS_SERVER_OAUTH2_TOKEN_EXPIRES_IN', 3600)

# Naive token storage implementation
_tokens = {}


class SimpleValidator(RequestValidator):
    """Validate username and password
    Note: does not support scopes or client_id"""

    def validate_client_id(self, client_id, request):
        return True

    def authenticate_client(self, request, *args, **kwargs):
        """Wide open"""
        request.client = type("Client", (), {'client_id': 'my_id'})
        return True

    def validate_user(self, username, password, client, request, *args, **kwargs):
        if username == QGIS_SERVER_OAUTH2_USERNAME and password == QGIS_SERVER_OAUTH2_PASSWORD:
            return True
        return False

    def validate_grant_type(self, client_id, grant_type, client, request, *args, **kwargs):
        # Clients should only be allowed to use one type of grant.
        return grant_type in ('password', 'refresh_token')

    def get_default_scopes(self, client_id, request, *args, **kwargs):
        # Scopes a client will authorize for if none are supplied in the
        # authorization request.
        return ('my_scope', )

    def validate_scopes(self, client_id, scopes, client, request, *args, **kwargs):
        """Wide open"""
        return True

    def save_bearer_token(self, token, request, *args, **kwargs):
        # Remember to associate it with request.scopes, request.user and
        # request.client. The two former will be set when you validate
        # the authorization code. Don't forget to save both the
        # access_token and the refresh_token and set expiration for the
        # access_token to now + expires_in seconds.
        _tokens[token['access_token']] = copy.copy(token)
        _tokens[token['access_token']]['expiration'] = time() + int(token['expires_in'])

    def validate_bearer_token(self, token, scopes, request):
        """Check the token"""
        return token in _tokens and _tokens[token]['expiration'] > datetime.now().timestamp()

    def validate_refresh_token(self, refresh_token, client, request, *args, **kwargs):
        """Ensure the Bearer token is valid and authorized access to scopes."""
        for t in _tokens.values():
            if t['refresh_token'] == refresh_token:
                return True
        return False

    def get_original_scopes(self, refresh_token, request, *args, **kwargs):
        """Get the list of scopes associated with the refresh token."""
        return []


validator = SimpleValidator()
oauth_server = LegacyApplicationServer(
    validator, token_expires_in=QGIS_SERVER_OAUTH2_TOKEN_EXPIRES_IN)

class OAuth2ResOwnerFilter(QgsServerFilter):
    """This filter provides testing endpoint for OAuth2 Resource Owner Grant Flow
    Available endpoints:
    - /token (returns a new access_token),
                optionally specify an expiration time in seconds with ?ttl=<int>
    - /refresh (returns a new access_token from a refresh token),
                optionally specify an expiration time in seconds with ?ttl=<int>
    - /result (check the Bearer token and returns a short sentence if it validates)
    """

    def responseComplete(self):

        handler = self.serverInterface().requestHandler()

        url = "%s//%s%s" % (
            ('https' if self.serverInterface().getEnv('HTTPS') else 'http'),
            self.serverInterface().getEnv('HTTP_HOST'),
            self.serverInterface().getEnv('REQUEST_URI'),
            )

        # To eneable the plugin the URL must contain oaut2 string
        if url.find('oauth2') == -1:
            return

        QgsMessageLog.logMessage("Response Complete from OAUTH2 REQUEST: %s"  % url)

        def _token(ttl):
            """Common code for new and refresh token"""
            handler.clearBody()
            handler.clearHeaders()
            body = self.serverInterface().getEnv('REQUEST_BODY')
            QgsMessageLog.logMessage("Response Complete from OAUTH2 REQUEST BODY: %s"  % body)
            #body = bytes(handle.data()).decode('utf8')
            old_expires_in = oauth_server.default_token_type.expires_in
            # Hacky way to dynamically set token expiration time
            oauth_server.default_token_type.expires_in = ttl
            headers, payload, code = oauth_server.create_token_response(
                'oauth2_token', 'post', body, {})
            oauth_server.default_token_type.expires_in = old_expires_in
            for k, v in headers.items():
                handler.setHeader(k, v)
            #handler.setStatusCode(code)
            QgsMessageLog.logMessage("Response Complete from OAUTH2 RESPONSE BODY: %s"  % payload.encode('utf-8'))
            handler.appendBody(payload.encode('utf-8'))

        # Token expiration
        ttl = handler.parameterMap().get('TTL', QGIS_SERVER_OAUTH2_TOKEN_EXPIRES_IN)
        # Issue a new token
        if url.find('oauth2_token') != -1:
            _token(ttl)
            return

        # Refresh token
        if url.find('oauth2_refresh') != -1:
            _token(ttl)
            return

        # Check for valid token
        auth = self.serverInterface().getEnv('HTTP_AUTHORIZATION')
        if auth:
            QgsMessageLog.logMessage("Response Complete from OAUTH2 AUTH: %s"  % auth)
            result, response = oauth_server.verify_request(
                urllib.quote_plus(handler.url(), safe='/:?=&'), 'post', '', {'Authorization': auth})
            if result:
                # This is a test endpoint for OAuth2, it requires a valid
                # token
                if url.find('oauth2_result') != -1:
                    handler.clear()
                    handler.appendBody(b'Valid Token: enjoy OAuth2')
                # Standard flow
                return
            else:
                # Wrong token, default response 401
                pass

        # No auth ...
        handler.clearBody()
        handler.clearHeaders()
        #handler.setStatusCode(401)
        handler.setHeader('Status', '401 Unauthorized')
        handler.setHeader(
            'WWW-Authenticate', 'Bearer realm="QGIS Server"')
        handler.appendBody(b'Invalid Token: Authorization required.')


class OAuth2ResOwner:

    def __init__(self, serverIface):
        # Save reference to the QGIS server interface
        self.filter = OAuth2ResOwnerFilter(serverIface)
        serverIface.registerFilter(self.filter, 100)

