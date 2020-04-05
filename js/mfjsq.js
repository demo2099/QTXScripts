/*
author:demo
群组https://t.me/demo2099
 */
var body=$response.body;



body.replace(/enable\":0/g,'enable":1'); $done({body});