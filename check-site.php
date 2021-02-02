<?php
include('check-site-params.php');
$message = date("Y-m-d H:i:s ")."Start check ".$argv[1]."\n";
echo($message);
print_r($argv);
$siteUrl = $argv[1];
if (strstr($siteUrl, DNSNAME)) {
  $seperated = explode('.', $siteUrl);
  $siteName = $seperated[0];
  $str1 = 'ansible-playbook /etc/ansible/playbooks/dns.yml -e "domain='.$siteUrl.' main_domain='.DNSNAME.'" -t findrecord';
  print($str1);
  $shellExecResult = shell_exec($str1);
  preg_match('/"stdout": "(\d+)",/', $shellExecResult, $match);
  $domain = $match[1];
  print($domain);
  if ($domain) {
    $dnsCheck = 1;
    echo("\n *** DNS check correct *** \n");
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
        echo("\n *** SMTP check correct ***\n");
      }
      else {
        $smtpCheck = 0;
        echo("\n *** SMTP check incorrect ***\n");
      }
    }
  }

  if (empty($argv[2])) {
    $email = NOTIFY_EMAIL;
  }
  else {
    $email = $argv[2];
  }
  $message = date("Y-m-d H:i:s ")."Site check finished: ".$argv[1]."\n";
  echo($message);
  $command = "/usr/bin/docker exec ".SEND_EMAIL_SITE." drush send-mail-check-site --to=$email --dns-check=$dnsCheck --smtp-check=$smtpCheck --site=$siteUrl";
  print($command."\n");
  $result = shell_exec($command);
  print($result."\n");
  if ($result) {
    $message = date("Y-m-d H:i:s ")."Send mail finished to ".$email."\n";
    echo($message);
    print("OK\n");
  }
}
