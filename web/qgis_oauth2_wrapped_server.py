# -*- coding: utf-8 -*-
"""
QGIS Server HTTP wrapper

This script launches a QGIS Server listening on port 8081 or on the port
specified on the environment variable QGIS_SERVER_PORT.
QGIS_SERVER_HOST (defaults to 127.0.0.1)

    
    QGIS_SERVER_LOG_LEVEL=0 QGIS_SERVER_LOG_FILE=/tmp/qgis-001.log QGIS_DEBUG=1 python qgis_wrapped_server.py

     
.. note:: This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
"""
from __future__ import print_function

import copy
import os
import sys
import urllib
from time import time

from future import standard_library
from http.server import BaseHTTPRequestHandler, HTTPServer
from oauthlib.oauth2 import LegacyApplicationServer, RequestValidator
from qgis.core import QgsMessageLog
from qgis.server import QgsServer, QgsServerFilter

standard_library.install_aliases()

__author__ = 'Alessandro Pasotti'
__date__ = '05/15/2016'
__copyright__ = 'Copyright 2016, The QGIS Project'
# This will get replaced with a git SHA1 when you do a git archive
__revision__ = '$Format:%H$'



QGIS_SERVER_PORT = int(os.environ.get('QGIS_SERVER_PORT', '8081'))
QGIS_SERVER_HOST = os.environ.get('QGIS_SERVER_HOST', '127.0.0.1')


qgs_server = QgsServer()


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


class Handler(BaseHTTPRequestHandler):

    def do_GET(self, data=None):
        # CGI vars:
        for k, v in self.headers.items():
            # Uncomment to print debug info about env vars passed into QGIS Server env
            #print('Setting ENV var %s to %s' % ('HTTP_%s' % k.replace(' ', '-').replace('-', '_').replace(' ', '-').upper(), v))
            qgs_server.putenv('HTTP_%s' % k.replace(' ', '-').replace('-', '_').replace(' ', '-').upper(), v)
        qgs_server.putenv('SERVER_PORT', str(self.server.server_port))
        qgs_server.putenv('SERVER_NAME', self.server.server_name)
        qgs_server.putenv('REQUEST_URI', self.path)
        if data is not None:
            qgs_server.putenv('REQUEST_BODY', data)
        parsed_path = urllib.parse.urlparse(self.path)
        headers, body = qgs_server.handleRequest(parsed_path.query)
        headers_dict = dict(h.split(': ', 1) for h in headers.decode().split('\n') if h)
        try:
            self.send_response(int(headers_dict['Status'].split(' ')[0]))
        except:
            self.send_response(200)
        for k, v in headers_dict.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)
        return

    def do_POST(self):
        content_len = int(self.headers.get('content-length', 0))
        post_body = self.rfile.read(content_len).decode()
        QgsMessageLog.logMessage("OAUTH2 POST BODY: %s"  % post_body)
        #request = post_body[1:post_body.find(' ')]
        #self.path = self.path + '&REQUEST=' + request
        return self.do_GET(post_body)



filter = OAuth2ResOwnerFilter(qgs_server.serverInterface())
qgs_server.serverInterface().registerFilter(filter, 100)

if __name__ == '__main__':
    server = HTTPServer((QGIS_SERVER_HOST, QGIS_SERVER_PORT), Handler)
    message = 'Starting server on %s://%s:%s, use <Ctrl-C> to stop' % \
              ('http', QGIS_SERVER_HOST, server.server_port)
    try:
        print(message, flush=True)
    except:
        print(message)
        sys.stdout.flush()
    server.serve_forever()
