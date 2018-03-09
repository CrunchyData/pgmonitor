# Grafana

The Grafana RPM Package can be downloaded and installed from https://grafana.com/grafana/download.

The steps to access the customized dashboards are as follows:

1. Connect to Grafana via https://&lt;ip-address&gt;:3000
1. Login as admin/admin
1. Change admin password
1. Add a Prometheus datasource. Ensure the resource matches what you setup for pgmonitor, e.g. `localhost:9090`
1. Download and import all dashboards to the datasource you created:
  - [PostgreSQL.json](PostgreSQL.json)
  - [PostgreSQLDetails.json](PostgreSQL.json)
  - [BloatDetails.json](BloatDetails.json)
  - [CRUD_Details.json](CRUD_Details.json)
  - [TableSize_Details.json](TableSize_Details.json)
  - [FilesystemDetails.json](FilesystemDetails.json)


### API Import

It is possible to import these graphs through the "import" HTTP API using the following curl command to add some required wrapper information to each json blob.

```bash
curl --user username:password -S "http://localhost:3000/api/dashboards/import" -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary "{  \"dashboard\" : $(cat PostgreSQL.json) , \"overwrite\":true, \"inputs\":[  {  \"name\":\"DS_PROMETHEUS\", \"type\":\"datasource\", \"pluginId\":\"prometheus\", \"value\":\"PROMETHEUS\" } ] }"
```
You will likely have to edit the following parts of the above command:

 - Username
 - Password
 - URL (and port if different from default)
 - The file to import goes in the `$cat()` parentheses. In the above example this is `PostgreSQL.json`.
 - In the above example, `"value: PROMETHEUS"` is your grafana datasource name for this dashboard. Replace `"PROMETHEUS"` with the proper datasource name.
