#!/bin/bash
# Setup QGIS
# - disable tips
# - enable the plugin

PLUGIN_NAME=$1
CONF_FOLDER="/root/.config/QGIS"
CONF_FILE="${CONF_FOLDER}/QGIS2.conf"
CONF_MASTER_FILE="${CONF_FOLDER}/QGIS2.conf" # Apparently the same ... (still 2.99)
QGIS_FOLDER="/root/.qgis2"
QGIS_MASTER_FOLDER="/root/.qgis-dev"
PLUGIN_FOLDER="${QGIS_FOLDER}/python/plugins"
PLUGIN_MASTER_FOLDER="${QGIS_MASTER_FOLDER}/python/plugins"

# Creates the config file
mkdir -p $CONF_FOLDER
if [ -e "$CONF_FILE" ]; then
    rm -f $CONF_FILE
fi
touch $CONF_FILE
if [ -e "$CONF_MASTER_FILE" ]; then
    rm -f $CONF_MASTER_FILE
fi
touch $CONF_MASTER_FILE

# Creates plugin folder
mkdir -p $PLUGIN_FOLDER
mkdir -p $PLUGIN_MASTER_FOLDER

# Disable tips
printf "[Qgis]\n" >> $CONF_FILE
printf "[Qgis]\n" >> $CONF_MASTER_FILE
SHOW_TIPS=`qgis --help 2>&1 | head -2 | grep 'QGIS - ' | perl -npe 'chomp; s/QGIS - (\d+)\.(\d+).*/showTips\1\2=false/'`
printf "$SHOW_TIPS\n\n" >> $CONF_FILE
printf "$SHOW_TIPS\n\n" >> $CONF_MASTER_FILE

if [ -n "$PLUGIN_NAME" ]; then
    # Enable plugin
    printf '[PythonPlugins]\n' >> $CONF_FILE
    printf "${PLUGIN_NAME}=true\n\n" >> $CONF_FILE

    printf '[PythonPlugins]\n' >> $CONF_MASTER_FILE
    printf "${PLUGIN_NAME}=true\n\n" >> $CONF_MASTER_FILE
fi
