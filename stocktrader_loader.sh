STOCKTRADER_LOCATION=$(dirname "$0")

#exit if errors are encountered

abort()
{
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred while loading stocktrader demo. Removing tmp directory and exiting…" >&2
    rm -r $STOCKTRADER_LOCATION/tmp
    exit 1
}

trap 'abort' 0

set -e

#ensure udclient location is set
if [ -z "$udclient" ]
then
    echo "Cannot find variable udclient. Please set the location of udclient."
    exit
fi

#ensure python is installed
if which python > /dev/null 2>&1;
then
    echo python detected
else
    echo attempting to install python…
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        echo linux os detected
        apt-get -y install python
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo mac os detected
        brew install python
    else
        echo An error occurred while detecting OS. Failed to install python.
    fi
fi

STOCKTRADER_LOCATION=$(dirname "$0")
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
echo creating tmp directory
echo

mkdir $STOCKTRADER_LOCATION/tmp

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

echo creating team
echo

$udclient createTeam -team "Container Team" > /dev/null

echo creating components
echo 

curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$STOCKTRADER_LOCATION/Component/stocktrader-all-in-one.yaml.json;type=application/zip" -F "filename=stocktrader-all-in-one.yaml.json" $DS_WEB_URL/rest/deploy/component/import > /dev/null

echo creating component versions
echo
$udclient createVersion -component stocktrader-all-in-one.yaml -name v1 > /dev/null
$udclient createVersion -component stocktrader-all-in-one.yaml -name v1-onprem-db > /dev/null

echo adding files to versions
echo
$udclient addVersionFiles -component stocktrader-all-in-one.yaml -version v1 -base $STOCKTRADER_LOCATION/Component/v1/ > /dev/null
$udclient addVersionFiles -component stocktrader-all-in-one.yaml -version v1-onprem-db -base $STOCKTRADER_LOCATION/Component/v1-onprem-db/ > /dev/null

echo creating application
echo

applicationId=`$udclient createApplication $STOCKTRADER_LOCATION/Applications/StockTrader.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`

echo adding component to application
echo

$udclient addComponentToApplication -component stocktrader-all-in-one.yaml -application StockTrader > /dev/null

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

$udclient createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/localenv.json > /dev/null
$udclient createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/qaenv.json > /dev/null
$udclient createEnvironmentFromTemplate $STOCKTRADER_LOCATION/tmp/prodenv.json > /dev/null

echo adding component templates to team
echo

$udclient addComponentTemplateToTeam -componentTemplate "Kubernetes Component Template" -team "Container Team" > /dev/null
$udclient addComponentTemplateToTeam -componentTemplate "Docker Template" -team "Container Team" > /dev/null

echo adding resources to team
echo

$udclient addResourceToTeam -resource "/StockTrader" -team "Container Team" > /dev/null

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