#set the location variable for stocktrader project
STOCKTRADER_LOCATION=$(dirname "$0")
UCD_SERVER_HOME=/opt/ibm-ucd/server

#exit if errors are encountered

abort()
{
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred while loading stocktrader demo. Removing tmp directory and exiting..." >&2
    rm -r $STOCKTRADER_LOCATION/tmp
    exit 1
}

trap 'abort' 0

set -e

echo creating tmp directory
echo

mkdir $STOCKTRADER_LOCATION/tmp

echo checking for urbancode deploy
echo

file="$UCD_SERVER_HOME/bin/server"
if [ ! -e "$file" ]; then
    echo "Installing IBM UrbanCode Deploy..."
    
    #install urbancode deploy
    if ls $STOCKTRADER_LOCATION/server/ibm-ucd*.zip 1> /dev/null 2>&1; then
        echo unzip -q $STOCKTRADER_LOCATION/server/ibm-ucd*.zip -d $STOCKTRADER_LOCATION/tmp
        unzip -q $STOCKTRADER_LOCATION/server/ibm-ucd*.zip -d $STOCKTRADER_LOCATION/tmp
    else
        echo "No install image found. $STOCKTRADER_LOCATION/server/ibm-ucd*.zip"
        exit 1
    fi

    echo "configuring mysql"
    echo

    #installing mysql connector jar
    apt-get install libmysql-java -y
    cp /usr/share/java/mysql.jar $STOCKTRADER_LOCATION/tmp/ibm-ucd-install/lib/ext/mysql.jar


    #set install properties and install the server
    cat $STOCKTRADER_LOCATION/server/supplemental-install-common.properties >>$STOCKTRADER_LOCATION/tmp/ibm-ucd-install/install.properties
    cat $STOCKTRADER_LOCATION/server/supplemental-install.properties >>$STOCKTRADER_LOCATION/tmp/ibm-ucd-install/install.properties
    echo "" >>$STOCKTRADER_LOCATION/tmp/ibm-ucd-install/install.properties
    echo "install.server.dir=$UCD_SERVER_HOME" >>$STOCKTRADER_LOCATION/tmp/ibm-ucd-install/install.properties
    echo
    echo install properties set. installing ucd server

    $STOCKTRADER_LOCATION/tmp/ibm-ucd-install/install-server.sh
fi

echo "IBM UrbanCode Deploy is installed"
echo

#ensure udclient location is set
if [ -z "$UD_CLIENT" ]
then
    echo extracting udclient from server
    unzip /opt/ibm-ucd/server/opt/tomcat/webapps/ROOT/tools/udclient.zip -d $STOCKTRADER_LOCATION/tmp/
    UD_CLIENT=$STOCKTRADER_LOCATION/tmp/udclient/udclient
    echo UD_CLIENT variable set to $UD_CLIENT
fi

#ensure necessary apps are installed
if which python > /dev/null 2>&1;
then
    echo python detected
    echo
else
    echo attempting to install python…
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        echo linux os detected
        apt-get -y install python unzip curl \
        && apt-get autoclean \
        && apt-get clean \
        && apt-get autoremove
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo mac os detected
        brew install python
    else
        echo An error occurred while detecting OS.
    fi
fi

export DS_USERNAME=admin
export DS_PASSWORD=admin
export DS_WEB_URL=https://localhost:8443

echo loading plugins
echo

curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/plugins/kubernetes-11.935934.zip;type=application/zip" -F "filename=kubernetes-11.935934.zip" $DS_WEB_URL/rest/plugin/automationPlugin
curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/plugins/docker-plugin-9.927770.zip;type=application/zip" -F "filename=docker-plugin-9.927770.zip" $DS_WEB_URL/rest/plugin/automationPlugin
curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/plugins/DockerSourceConfig-22.937762.zip;type=application/zip" -F "filename=DockerSourceConfig-22.937762.zip" $DS_WEB_URL/rest/plugin/sourceConfigPlugin

echo
echo

echo downloading templates from github
echo

curl -k https://raw.githubusercontent.com/IBM-UrbanCode/Templates-UCD/master/Kubernetes/Tutorial/KubernetesComponentTemplate.json > $STOCKTRADER_LOCATION/tmp/KubernetesComponentTemplate.json
curl -k https://raw.githubusercontent.com/IBM-UrbanCode/Templates-UCD/master/Docker/componenttemplates/Docker%2BTemplate.json > $STOCKTRADER_LOCATION/tmp/Docker+Template.json
curl -k https://raw.githubusercontent.com/IBM-UrbanCode/Templates-UCD/master/Kubernetes/Tutorial/KubernetesApplicationTemplate.json > $STOCKTRADER_LOCATION/tmp/KubernetesApplicationTemplate.json

echo
echo importing templates
echo

curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/tmp/Docker+Template.json;type=application/zip" -F "filename=Docker+Template.json" $DS_WEB_URL/rest/deploy/componentTemplate/import > /dev/null
curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/tmp/KubernetesApplicationTemplate.json;type=application/zip" -F "filename=KubernetesApplicationTemplate.json" $DS_WEB_URL/rest/deploy/applicationTemplate/import?resourceTemplateUpgradeType=UPGRADE_IF_EXISTS > /dev/null

echo creating components
echo 

curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/Component/stocktrader-all-in-one.yaml.json;type=application/zip" -F "filename=stocktrader-all-in-one.yaml.json" $DS_WEB_URL/rest/deploy/component/import > /dev/null

echo creating component versions
echo
$UD_CLIENT createVersion -component stocktrader-all-in-one.yaml -name v1 > /dev/null
$UD_CLIENT createVersion -component stocktrader-all-in-one.yaml -name v1-onprem-db > /dev/null

echo adding files to versions
echo
$UD_CLIENT addVersionFiles -component stocktrader-all-in-one.yaml -version v1 -base $STOCKTRADER_LOCATION/Component/v1/ > /dev/null
$UD_CLIENT addVersionFiles -component stocktrader-all-in-one.yaml -version v1-onprem-db -base $STOCKTRADER_LOCATION/Component/v1-onprem-db/ > /dev/null

echo creating application
echo

applicationId=`$UD_CLIENT createApplication $STOCKTRADER_LOCATION/Applications/StockTrader.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`

echo adding component to application
echo

$UD_CLIENT addComponentToApplication -component stocktrader-all-in-one.yaml -application StockTrader > /dev/null

echo creating environments
echo

echo "{
  \"applicationId\": \"$applicationId\",
  \"name\": \"LOCAL 1\",
  \"templateName\": \"LOCAL\"
}" > $STOCKTRADER_LOCATION/tmp/localenv.json

echo "{
  \"applicationId\": \"$applicationId\",
  \"name\": \"QA 1\",
  \"templateName\": \"QA\"
}" > $STOCKTRADER_LOCATION/tmp/qaenv.json

echo "{
  \"applicationId\": \"$applicationId\",
  \"name\": \"PROD 1\",
  \"templateName\": \"PROD\"
}" > $STOCKTRADER_LOCATION/tmp/prodenv.json

localenvId=`$UD_CLIENT createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/localenv.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`
qaenvId=`$UD_CLIENT createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/qaenv.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`
prodenvId=`$UD_CLIENT createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/prodenv.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`

echo setting environment properties
echo

curl -k -X PUT -u $DS_USERNAME:$DS_PASSWORD "$DS_WEB_URL/cli/environment/propValue?environment=$localenvId&name=KUBECTL-OPTS&value=" > /dev/null
curl -k -X PUT -u $DS_USERNAME:$DS_PASSWORD "$DS_WEB_URL/cli/environment/propValue?environment=$qaenvId&name=KUBECTL-OPTS&value=" > /dev/null
curl -k -X PUT -u $DS_USERNAME:$DS_PASSWORD "$DS_WEB_URL/cli/environment/propValue?environment=$prodenvId&name=KUBECTL-OPTS&value=" > /dev/null

echo removing tmp directory
echo
rm -r $STOCKTRADER_LOCATION/tmp

echo stocktrader application loaded successfully

trap : 0

echo >&2 '
************
*** DONE ***
************
'