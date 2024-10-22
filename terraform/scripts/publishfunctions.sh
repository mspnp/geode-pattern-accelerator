#! /bin/bash

terraformDirectory=$1
functionAppDirectory=$2
currentDirectory=$(pwd)

echo "Changing directory to $terraformDirectory"
cd "$terraformDirectory"

echo "Retrieving Terraform outputs"

functionApps=$(terraform output function_apps)
resourceGroup=$(terraform output resource_group)

# trim quotes from resource group output value
resourceGroup=$(echo $resourceGroup| cut -d'"' -f 2)

echo "resourceGroup: $resourceGroup"
echo "functionApps: $functionApps"

echo "Reverting to initial directory"
cd "$currentDirectory"

echo "Changing directory to $functionAppDirectory"
cd "$functionAppDirectory"

exitcode=0
for app in $functionApps; do

  # ensure function app name output value is valid
  if [[ "$app" == 'null' || "$app" == *"["*  || "$app" == *"]"*  ]]; then
    continue
  fi
  
  if [[ $app == *","* ]]; then
    app=${app%,*}
  fi
  
  app="${app//\"}"
  echo "Starting $app before publishing code"
  az functionapp start -g "$resourceGroup" -n "$app" >/dev/null

  echo "Publishing to $app"
  func azure functionapp publish $app --dotnet-isolated
  for ((i = 0; $? != 0 && $i < 10; i++)); do
    # Echoes in Red
    echo -e "\e[31m[$i] Failed ($?). Waiting 1 minute and trying again...\e[0m"
    sleep 1m
    func azure functionapp publish $app --dotnet-isolated
  done

  if [[ $? != 0 ]]; then
    echo -e "\e[31mToo many failures while trying to deploy $app \e[0m"
    exitcode=1
  fi

done

exit $exitcode