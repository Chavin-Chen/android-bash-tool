<?php
/*
loc:/tool/sh/mtu.php
dev push ./mtu.php /var/www/html/tool/sh/mtu.php

db:
CREATE DATABASE mt_db;
CREATE TABLE mt_user(id INT(11) PRIMARY KEY AUTO_INCREMENT,usr VARCHAR(60),ip VARCHAR(20),day INT,shells TEXT,create_ts NOT NULL DEFAULT CURRENT_TIMESTAMP)AUTO_INCREMENT=1;
GRANT ALL ON mt_db.* TO www-data@localhost IDENTIFIED BY PASSWORD password('www-data123');

 */
$usr = $_POST['u'];
$ip = $_POST['i'];
$ts = $_POST['t'];
$shells = $_POST['s'];

if (empty($usr) || empty($ip) || empty($ts) || empty($shells)) {
    echo "<html><head><title>404 Not Found</title></head><body bgcolor='white'><center><h1>404 Not Found</h1></center><hr><center>nginx/1.10.3</center></body></html>";
    return;
}
try {
    $d = (int)((int)$ts / 86400);
    $conn = new PDO('mysql:host=localhost:3306;dbname=mt_db', 'www-data', 'www-data123');

    $read = $conn->prepare("SELECT count(id) FROM mt_user WHERE day=:day AND ip=:ip AND usr=:usr;");
    $read->execute(array(":usr" => "$usr", ":ip" => "$ip", ":day" => $d));
    $cnt = $read->fetch();

    if ($cnt[0] > 0) {
        echo "failed:the same day post twice";
        return;
    }

    $write = $conn->prepare("INSERT mt_user (usr, ip, day, shells) VALUES (:usr, :ip, :day, :shells);");
    $write->execute(array(":usr" => "$usr", ":ip" => "$ip", ":day" => "$d", ":shells" => "$shells"));
    $res = $write->rowCount();
    if ($res > 0) {
        echo "succeed";
    } else {
        echo "failed:save error";
    }
} catch (PDOException $e) {
    echo "failed:conn error <br/>";
    echo $e->getMessage();
} finally {
    $conn = null;
}
