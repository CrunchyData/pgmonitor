The files in this directory are made to be imported to Grafana via its HTTP import API. The only editing that needs to be done beforehand is to set the name of the datasource at the bottom input section of each file. For example, in the PostgreSQL_API.json file, edit the "value" column at the bottom to match the datasource name in your Grafana instance:

```
   "inputs":[  
      {  
         "name":"DS_DATABASE1",
         "type":"datasource",
         "pluginId":"prometheus",
         "value":"PROMETHEUS"
      }
   ]
```

Once that is done, the following curl command can be used to import the dashboards:

    curl -Ssl "http://admin:admin@localhost:3000/api/dashboards/import" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary "$(cat PostgreSQL_API.json)"

Set username, password & host as necessary. Replace the filename in the $cat() command with the filename of the dashboard being imported.
