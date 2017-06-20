# -*- coding: utf-8 -*-
"""
 This script initializes the plugin, making it known to QGIS.
"""


def serverClassFactory(serverIface):
    from . oauth2resowner import OAuth2ResOwner
    return OAuth2ResOwner(serverIface)
