# ucd-stocktrader-loader

This project contains a shell script which installs a UCD server and loads it with the stocktrader project which showcases deploying to IBM Cloud Private.

## Getting Started

1. If UCD is not already installed locally, place the ibm-ucd*.zip in the server directory folder of the project.

2. Locate and update the server location, credentials, and web url for UCD in the stocktrader_loader.sh script if necessary:

Defaults:  
UCD_SERVER_HOME=/opt/ibm-ucd/server  
DS_USERNAME=admin  
DS_PASSWORD=admin  
DS_WEB_URL=https://localhost:8443  

3. Run the script, follow the prompts, noting any errors returned.

