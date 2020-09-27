/*
author:demo
群组https://t.me/demo2099
https://api.cercube.com/v2/user
 */
 var body = $response.body;
let url=$request.url;
if($request.url.indexOf("user/info") != -1){
body=body.replace(/type\":\"\d/g,'type":"4').replace(/vip_expire\":\"\d+/g,'vip_expire":"5201314007');
var body = JSON.parse(body); 
body.data.info.avatar="https://s1.ax1x.com/2020/09/20/w7lOEQ.gif";
body.data.info.vip=1;
body.data.info.nickname="呆猫demo";let coin={
        "new_cash": "5201314.00",
        "new_coin": "5200"
      };
      body.data.info.withdraw_data=coin;
      body.data.info.cash=5201314.00;
}else if($request.url.indexOf("user_welfare/add_free_chapter_record") != -1){
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

