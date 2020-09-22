/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
let url=$request.url;
if(url.endsWith("access_token")) {
	$done({});
}else{
var body = $response.body;
body={
  "id" : 386641,
  "updatedAt" : "2020-04-08T07:55:03.413Z",
  "lastName" : "demo",
  "firstName" : "mt",
  "blocked" : false,
  "roleId" : 1,
  "didMigrate" : true,
  "countryCode" : "CN",
  "customerId" : "cus_H3g6yrkdYeL0Lh",
  "username" : "demo2099",
  "subscriptions" : [

  ],
  "email" : "xxxx@gmail.com"
};

body = JSON.stringify(obj);
$done({
    body
});
}
