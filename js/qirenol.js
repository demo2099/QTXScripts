/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
if($request.url.indexOf("user_welfare/add_free_chapter_record") != -1){
body={
  "status" : "success",
  "code" : 1,
  "data" : {

  },
  "msg" : "ok"
};
}else if($request.url.indexOf("chapter/showUnlockCharpterPanel") != -1){
body={
  "status": "success",
  "code": 1,
  "msg": "ok",
  "data": {
    "price": 1.5,
    "vipprice": 0,
    "balance": 10,
    "bookvoucher": 10,
    "enough": 10,
    "priceWord": 0.07
  }
};
}else if($request.url.indexOf("user/unlockCharpter") != -1){

body={
  "status": "success",
  "code": 1,
  "msg": "ok",
  "data": {

  }
};
}
;

body = JSON.stringify(body);
$done({
    body
});

