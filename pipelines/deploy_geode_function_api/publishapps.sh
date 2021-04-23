#! /bin/bash

if [[ $# < 2 ]]; then
  echo "output dir, output file required"
  exit 1
fi


outputDir=$1
outputFile=$2
lang="csharp"
seedFunctionApp=""

echo
echo "lang: $lang"
echo "outputDir: $outputDir"
echo "outputFile: $outputFile"
echo

exitcode=0
for app in $(jq -r '.[0]' $outputDir/$outputFile); do
  
  echo "Validating function app name"
  if [[ "$app" == 'null' || "$app" == *"["*  || "$app" == *"]"*  ]]; then
    continue
  fi
  
  if [[ $app == *","* ]]; then
    app=${app%,*}
  fi
  
  app="${app//\"}"
  rg=$(jq -r '.[3]' $outputDir/$outputFile)
  localsettings="$outputDir/app_settings/"$app"_app_settings.json"
  seedFunctionApp=$app

  echo
  echo "rg: $rg"
  echo "localsettings: $localsettings"
  echo

  echo "Applying settings from $(basename ${localsettings}) into $app with rg $rg"
  az functionapp config appsettings set -g "$rg" -n "$app" --settings @"$(echo ${localsettings})" >/dev/null
  echo "Settings applied for $(basename ${localsettings})"

  echo "Starting $app before publishing code..."
  az functionapp start -g "$rg" -n "$app" >/dev/null

  echo "Publishing to $app ..."

  buildArg="--no-build"

  echo "func azure functionapp publish $app --$lang $buildArg"
  func azure functionapp publish $app --$lang $buildArg
  for ((i = 0; $? != 0 && $i < 10; i++)); do
    # Echoes in Red
    echo -e "\e[31m[$i] Failed ($?). Waiting 1 minute and trying again...\e[0m"
    sleep 1m
    func azure functionapp publish $app --$lang $buildArg
  done

  if [[ $? != 0 ]]; then
    echo -e "\e[31mToo many failures while trying to deploy $app \e[0m"
    exitcode=1
  fi

  echo "Removing AzureWebJobsDashboard app setting..."
  az functionapp config appsettings delete -g "$rg" -n "$app" --setting-names AzureWebJobsDashboard

  echo "Stopping $app ..."
  az functionapp stop -g "$rg" -n "$app" >/dev/null

done

echo "Ensuring $seedFunctionApp function app is running for database seed"
az functionapp start -g "$rg" -n "$seedFunctionApp" >/dev/null

echo "Giving function app time to warm up"
sleep 1m

appState=$(az functionapp show -g "$rg" -n "$seedFunctionApp" --query state -otsv)
while [ $appState != "Running" ] 
do
    echo -e "\e[31mApplication state is $appState. Waiting 1 minute and trying again...\e[0m"
    sleep 1m
    appState=$(az functionapp show -g "$rg" -n "$seedFunctionApp" --query state -otsv)
done

url="https://$seedFunctionApp.azurewebsites.net/api/SeedData"
echo "Sending request to seed data to $url"

echo $(curl -s --location --request POST "$url" --header 'Content-Type: application/json' --data-raw '{"warehouseCount":500,"maxParallelism":20}')

echo "Stopping function"
az functionapp stop -g "$rg" -n "$seedFunctionApp" >/dev/null

exit $exitcode