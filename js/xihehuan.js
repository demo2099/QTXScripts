/*
author:demo
群组https://t.me/demo2099


*/

var body=$response.body;var obj=JSON.parse(body);obj.endTime="2030-12-30",obj.data.leftDay=999999,obj.data.isVip=1,obj.data.vipType=2,obj.data.diamond=99999,obj.data.yuanBao=99999,obj.data.cash=999999,obj.data.vcoin=99999,body=JSON.stringify(obj);$done({body});
