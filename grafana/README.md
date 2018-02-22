# Grafana

The Grafana RPM Package can be downloaded and installed from https://grafana.com/grafana/download.

The steps to access the customized dashboards are as follows:

* Connect to Grafana via https://&gt;ip-address&lt;:3000
* Login as admin/admin
* Change admin password
* Add Prometheus datasource
* Import all dashboards 
  * PostgreSQL.json
  * PostgreSQLDetails.json
  * BloatDetails.json
  * CRUD_Details.json
  * TableSize_Details.json
  * FilesystemDetails.json


### API Import

It is possible to import these graphs through the "import" HTTP API using the following curl command to add some required wrapper information to each json blob. 
```
curl --user username:password -S "http://localhost:3000/api/dashboards/import" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary "{  \"dashboard\" : $(cat PostgreSQL.json) , \"overwrite\":true, \"inputs\":[  {  \"name\":\"DS_PROMETHEUS\", \"type\":\"datasource\", \"pluginId\":\"prometheus\", \"value\":\"PROMETHEUS\" } ] }"
```
You will likely have to edit the following parts of the above command:

 * Username
 * Password
 * URL (and port if different from default)
 * The file to import goes in the $cat() parentheses. In the above example this is "PostgreSQL.json".
 * In the above example, "value: PROMETHEUS" is your grafana datasource name for this dashboard. Replace "PROMETHEUS" with the proper datasource name.



