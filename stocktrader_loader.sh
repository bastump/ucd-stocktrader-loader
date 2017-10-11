#ensure udclient and stocktrader_location variables are set
if [ -z "$udclient" ]
then
    echo "Cannot find variable udclient"
    exit
fi
if [ -z "$STOCKTRADER_LOCATION" ]
then
    echo "Cannot find variable STOCKTRADER_LOCATION"
    exit
fi



curl -k —verbose -u $DS_USERNAME:$DS_PASSWORD -s --insecure -F "file=@$JKE_LOCATION/plugins/WebSphereLiberty-7.778014.zip;type=application/zip" -F "filename=WebSph
ereLiberty-7.778014.zip" $DS_WEB_URL/rest/plugin/automationPlugin


echo creating kubernetes component template
echo 

kubernetesTemplateId=`$udclient createComponentTemplate $STOCKTRADER_LOCATION/ComponentTemplates/Kubernetes+Component+Template.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`

echo creating docker template
echo 

dockerTemplateId=`$udclient createComponentTemplate $STOCKTRADER_LOCATION/ComponentTemplates/Docker+Template.json | python -c \
"import json; import sys;
data=json.load(sys.stdin); print data['id']"`

echo setting component prop refs

curl -k -u $DS_USERNAME:$DS_PASSWORD \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d "
  {
    \"description\": \"Name of the Docker image to use with this component. i.e. tomcat, nginx, ubuntu\",
    \"label\": \"Docker Image Name\",
    \"name\": \"docker.image.name\",
    \"pattern\": \"\",
    \"required\": \"false\",
    \"type\": \"TEXT\",
    \"value\": \"\"
  }
" \
""$DS_WEB_URL"/property/propSheetDef/componentTemplates&"$dockerTemplateId"&propSheetDef.-1/propDefs" 1>/dev/null

curl -k -u $DS_USERNAME:$DS_PASSWORD \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d "
  {
    \"description\": \"Name to pass into pull command, in the form, [REGISTRY_HOST[:REGISTRY_PORT]\/]NAME[:TAG]\",
    \"label\": \"Fully Qualified Docker Image\",
    \"name\": \"docker.qualified.image\",
    \"pattern\": \"\",
    \"required\": \"true\",
    \"type\": \"TEXT\",
    \"value\": \"\${p?:docker.registry}\${p:docker.image.name}:\${p:version/dockerImageTag}\"
  }
" \
""$DS_WEB_URL"/property/propSheetDef/componentTemplates&"$dockerTemplateId"&propSheetDef.-1/propDefs" 1>/dev/null

curl -k -u $DS_USERNAME:$DS_PASSWORD \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d "
  {
    \"description\": \"Location of the docker registry used in pull commands\",
    \"label\": \"Docker Registry\",
    \"name\": \"docker.registry\",
    \"pattern\": \"\",
    \"required\": \"false\",
    \"type\": \"TEXT\",
    \"value\": \"\"
  }
" \
""$DS_WEB_URL"/property/propSheetDef/componentTemplates&"$dockerTemplateId"&propSheetDef.-1/propDefs" 1>/dev/null

curl -k -u $DS_USERNAME:$DS_PASSWORD \
     -H 'Content-Type: application/json' \
     -X PUT \
     -d "
  {
    \"description\": \"Name to assign to the running docker container\",
    \"label\": \"Container Name\",
    \"name\": \"docker.container.name\",
    \"pattern\": \"\",
    \"required\": \"false\",
    \"type\": \"TEXT\",
    \"value\": \"\${p:docker.image.name}-\${p:environment.name}\"
  }
" \
""$DS_WEB_URL"/property/propSheetDef/componentTemplates&"$dockerTemplateId"&propSheetDef.-1/propDefs" 1>/dev/null


echo creating team
echo

$udclient createTeam -team "Container Team" 1> /dev/null

echo adding component templates to team
echo

$udclient addComponentTemplateToTeam -componentTemplate "Kubernetes Component Template" -team "Container Team" 1> /dev/null
$udclient addComponentTemplateToTeam -componentTemplate "Docker Template" -team "Container Team" 1> /dev/null

echo creating components
echo 

$udclient createComponent $STOCKTRADER_LOCATION/Components/stocktrader-all-in-one.yaml.json 1> /dev/null
$udclient createComponent $STOCKTRADER_LOCATION/Components/StockTrader-loyalty-level.json 1> /dev/null
$udclient createComponent $STOCKTRADER_LOCATION/Components/StockTrader-portfolio.json 1> /dev/null
$udclient createComponent $STOCKTRADER_LOCATION/Components/StockTrader-stock-quote.json 1> /dev/null
$udclient createComponent $STOCKTRADER_LOCATION/Components/StockTrader-notification.json 1> /dev/null
$udclient createComponent $STOCKTRADER_LOCATION/Components/StockTrader-trader.json 1> /dev/null

echo setting properties on components
echo 

$udclient setComponentProperty -component StockTrader-loyalty-level -name docker.registry.name -value master.cfc:8500 1>/dev/null
$udclient setComponentProperty -component StockTrader-portfolio -name docker.registry.name -value master.cfc:8500 1>/dev/null
$udclient setComponentProperty -component StockTrader-stock-quote -name docker.registry.name -value master.cfc:8500 1>/dev/null
$udclient setComponentProperty -component StockTrader-notification -name docker.registry.name -value master.cfc:8500 1>/dev/null
$udclient setComponentProperty -component StockTrader-trader -name docker.registry.name -value master.cfc:8500 1>/dev/null


echo creating processes on each component
echo 

$udclient createComponentProcess $STOCKTRADER_LOCATION/Components/Process+and+Apply+YAML+File.json 1> /dev/null


echo creating application
echo

$udclient createApplication $STOCKTRADER_LOCATION/Applications/StockTrader.json 1> /dev/null

echo adding components to application
echo

$udclient addComponentToApplication -component stocktrader-all-in-one.yaml -application StockTrader 1> /dev/null
$udclient addComponentToApplication -component StockTrader-loyalty-level -application StockTrader 1> /dev/null
$udclient addComponentToApplication -component StockTrader-portfolio -application StockTrader 1> /dev/null
$udclient addComponentToApplication -component StockTrader-stock-quote -application StockTrader 1> /dev/null
$udclient addComponentToApplication -component StockTrader-notification -application StockTrader 1> /dev/null
$udclient addComponentToApplication -component StockTrader-trader -application StockTrader 1> /dev/null



