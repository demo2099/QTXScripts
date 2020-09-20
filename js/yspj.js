/*
author:demo
群组https://t.me/demo2099
 */
 
var body=$response.body;
body={
  "retcode": 0,
  "errmsg": "",
  "data": {
    "user": {
      "uid": "20888",
      "uniqkey": "GXH6HE",
      "username": "demo2099",
      "nickname": "demo",
      "mobi": "86.13279316646",
      "email": "~1023687698",
      "sysgid": "0",
      "gid": "5",
      "gids": null,
      "gicon": "V5",
      "isvip": 1,
      "regtime": "2019-07-12 18:57:06",
      "gender": "2",
      "avatar": "04",
      "avatar_url": "https://s1.ax1x.com/2020/09/20/w7lOEQ.gif",
      "newmsg": "0",
      "goldcoin": 250,
      "duetime": "",
      "dueday": "tg群t.me/zhongleleQun"
    },
    "uinfo": {
      "goldcoin": "250",
      "play_daily_remainders": 5201314,
      "down_daily_remainders": 5201314,
      "curr_group": {
        "gid": "5",
        "gname": "尊贵VIP",
        "gicon": "V5",
        "minup": "20"
      },
      "next_group": {
        "gid": "6",
        "gname": "禁止发言",
        "gicon": "",
        "minup": "65535"
      },
      "next_upgrade_need": 65116
    },
    "signed": 0,
    "reqplay_addnum": "162",
    "reqdown_addnum": "0",
    "groups": [{
      "gname": "游客",
      "gicon": "V0",
      "minup": "0",
      "play_daynum": 15,
      "down_daynum": 0,
      "comment_daynum": 0
    }, {
      "gname": "VIP1",
      "gicon": "V1",
      "minup": "0",
      "play_daynum": 25,
      "down_daynum": 4,
      "comment_daynum": 5
    }, {
      "gname": "VIP2",
      "gicon": "V2",
      "minup": "2",
      "play_daynum": 50,
      "down_daynum": 10,
      "comment_daynum": 10
    }, {
      "gname": "VIP3",
      "gicon": "V3",
      "minup": "5",
      "play_daynum": 100,
      "down_daynum": 20,
      "comment_daynum": 15
    }, {
      "gname": "VIP4",
      "gicon": "V4",
      "minup": "10",
      "play_daynum": 200,
      "down_daynum": 40,
      "comment_daynum": 20
    }, {
      "gname": "尊贵VIP",
      "gicon": "V5",
      "minup": "20",
      "play_daynum": 999,
      "down_daynum": 100,
      "comment_daynum": 30
    }]
  }
};
body=JSON.stringify(body);
$done({body});
