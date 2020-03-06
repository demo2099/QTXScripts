/*

author:demo
群组https://t.me/demo2099

 */



//const path = "/api/public/";

//const url = $request.url;
var body = $response.body;


    var obj = JSON.parse(body);
    obj.msg.time = 1896192000;

body = JSON.stringify(obj);


$done({body});

