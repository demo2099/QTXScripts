/*
author:demo
群组https://t.me/demo2099
 */
var body=$response.body;body={
  "code": 0,
  "message": "执行成功",
  "data": {
    "userId": "289366047251759104",
    "phone": "guestA0C66F6B-964F-4E6D-8F5A-C805C9AED25E",
    "secretKey": "df9eb064-bc6a-4708-9afd-ce28e0676c30",
    "expired": false,
    "expireTime": "2222-02-22 18:26:32",
    "loginTime": "2020-03-16 19:43:57",
    "createTime": "2020-03-10 23:54:48",
    "signedToday": true,
    "signedDays": 5201314,
    "signedDuration": 15
  }
}
;body=JSON.stringify(body);$done({body});
