<?php
include('check-site-params.php');
print_r($argv);
$siteUrl = $argv[1];
if (strstr($siteUrl, DNSNAME)) {
  $seperated = explode('.', $siteUrl);
  $siteName = $seperated[0];
  $str1 = "linode -o domain -a record-list -l ".DNSNAME." -t CNAME | grep '{$siteName}' | awk -F ' *| *' '{print \$6}'";
  print($str1);
  $domain = shell_exec($str1);
  print($domain);
  if ($domain) {
    $dnsCheck = 1;
    print("\n *** DNS check correct *** \n");
    if ($domain) {
      $command = 'ping -c 1 '.$siteUrl;
      $result = shell_exec($command);
      print($result);
      $search = '/bytes from (.+) \(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\)/';
      preg_match($search, $result, $match);
      print_r($match);
      $vpsName = $match[1];
      $command = "ssh ".USER."@$vpsName cat /var/www/sites/$siteUrl/sites/default/settings.php | grep 'smtp.settings.php'";
      $result = shell_exec($command);
      print($result);
      $command = "ssh ".USER."@$vpsName cat /var/www/sites/$siteUrl/sites/default/smtp.settings.php | grep '$siteUrl'";
      $result = shell_exec($command);
      print($result);
      print("\n");
      if (strpos($result, $siteUrl)) {
        $smtpCheck = 1;
        print("\n *** SMTP check correct ***\n");
      }
      else {
        $smtpCheck = 0;
        print("\n *** SMTP check incorrect ***\n");
      }
    }
  }

  if (empty($argv[2])) {
    $email = NOTIFY_EMAIL;
  }
  else {
    $email = $argv[2];
  }
  $command = "docker exec -it ".SEND_EMAIL_SITE." drush send-mail-check-site --to=$email --dns-check=$dnsCheck --smtp-check=$smtpCheck --site=$siteUrl";
  print($command."\n");
  $result = shell_exec($command);
  print($result."\n");
  if ($result) {
    print("OK\n");
  }
}
