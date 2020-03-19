/*
author:demo
群组https://t.me/demo2099
 */
var body=$response.body;body={
  "code": 0,
  "message": "执行成功",
  "data": {
    "userId": "289366047251759104",
    "phone": "guest512F5B34-D7DD-4190-93BA-FA0EF4F6E5D7",
    "secretKey": "df9eb064-bc6a-4708-9afd-ce28e0676c30",
    "expired": false,
    "expireTime": "2077-07-07 21:22:04",
    "loginTime": "2020-03-19 20:52:04",
    "createTime": "2020-03-19 20:52:04",
    "signedToday": true,
    "signedDays": 1,
    "signedDuration": 15
  }
};body=JSON.stringify(body);$done({body});
