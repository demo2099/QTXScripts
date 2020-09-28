/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
if(url.endsWith("access_token")){
body={
  "token" : "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6Mzg2NjQxLCJpYXQiOjE2MDA3NjQ1OTIsImV4cCI6MTYwMDc3MTc5Mn0.cG0zmgFBZCB8nuXo1K2_FeIrSokUb20SJ59CbpcECg8"
};
body=JSON.stringify(body);$done({body});
}else if(url.endsWith("login")) {
$done({
    body
});
}else{

console.log("进来了")
body={
  "id" : 386641,
  "updatedAt" : "2020-04-08T07:55:03.413Z",
  "lastName" : "li",
  "firstName" : "mt",
  "blocked" : false,
  "roleId" : 1,
  "didMigrate" : true,
  "countryCode" : "CN",
  "customerId" : "cus_H3g6yrkdYeL0Lh",
  "username" : "liavailable",
  "subscriptions" : [

  ],
  "email" : "hao1454507493@gmail.com",
  "createdAt" : "2020-02-22T05:28:53.541Z"
}
;

body = JSON.stringify(body);
$done({
    body
});
}
