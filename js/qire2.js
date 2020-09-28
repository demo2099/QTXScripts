/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
body={
  "status" : "error",
  "code" : 0,
  "data" : {

  },
  "msg" : "ok"
};
body = JSON.stringify(body);
$done({
    body
});
