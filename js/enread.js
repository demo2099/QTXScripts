/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
if(url.endsWith("QueryVipUser")){
body={
  "isVip": true,
  "code": 200,
  "expireDays": 5201314
};
}

body=JSON.stringify(body);$done({body});

