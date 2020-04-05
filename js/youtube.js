/*
author:demo
群组https://t.me/demo2099
 */

var body = $response.body;
var user = {};
var obj = JSON.parse(body);
obj.status = "E_OKAY";
obj.code = 0;
obj.user = {
    "blocked": false,
    "roleId": 1,
    "didMigrate": true,
    "createdAt": "2020-02-22T05:28:53.541Z",
    "updatedAt": "2020-03-01T22:08:26.046Z"
};
body = JSON.stringify(obj);
$done({
    body
});