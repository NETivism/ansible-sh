#!/usr/bin/php
<?php

if (!isset($argv[1]) || !isset($argv[2])) {
  print 'Usage: sudo php update_container.php [target] [repository]'.PHP_EOL;
  print 'Dry-run Usage: sudo php update_container.php [target] [repository] check'.PHP_EOL;
  print 'Example: sudo php update_container.php vps-abc netivism/docker-wheezy-php55:fpm'.PHP_EOL;
  exit;
}

$target = $argv[1];
$repo = $argv[2];
$dryrun = (isset($argv[3]) && $argv[3] == 'check') ? true : false;

$cmd = "ansible $target -m command -a 'list-domain-by-specific-repo.sh $repo'";
exec($cmd, $domains, $rc);

if ($rc !== 0) {
  echo "No such remote detect.".PHP_EOL;
  exit(1);
}

if (!strstr($domains[0], 'success')) {
  echo "Fail result".PHP_EOL;
  exit(1);
}

$domains = array_slice($domains, 1, -1);

if (empty($domains[0])) {
  echo "Empty result".PHP_EOL;
}

print 'Estimated execution...'.PHP_EOL;
print implode(PHP_EOL, $domains);
print PHP_EOL.'======'.PHP_EOL;
print 'Go...'.PHP_EOL;

foreach ($domains as $domain) {
  $cfg = json_decode(file_get_contents("/etc/ansible/target/{$target}/{$domain}"));

  if (empty($cfg)) {
    _log($target, $domain, 'N/A', 'No such config');
    continue;
  }

  if ($cfg->status != 1) {
    _log($target, $domain, $cfg->mount, 'Site offline');
    continue;
  }

  print 'updating '.$cfg->domain.PHP_EOL;

  if ($cfg->mount == '/mnt/neticrm-7') {
    _update_container($target, $cfg);
    sleep(30);
    _ping_domain($target, $cfg);
    _list_smtp($target, $cfg);
  }

  if ($cfg->mount == '/mnt/neticrm-6') {
    _log($target, $cfg->domain, $cfg->mount, '=skip');
  }
}

function _list_smtp($target, $cfg) {
  $cmd =<<<CMD
ansible {$target} -m shell -a "docker exec -i {$cfg->domain} bash -c 'drush -l {$cfg->domain} sqlq \"select filename from system where name='\"'smtp'\"' and status=1;\"'"
CMD;
  $ret = shell_exec($cmd);
  $ret = '=smtp' . PHP_EOL . '======' . PHP_EOL . $ret . PHP_EOL . '======';
  _log($target, $cfg->domain, $cfg->mount, $ret);
}

function _update_container($target, $cfg) {
  if ($GLOBALS['dryrun']) {
    print 'dry-run execution...'.PHP_EOL;
    $cmd = "ansible-playbook /etc/ansible/playbooks/docker.yml -e @/etc/ansible/target/{$target}/{$cfg->domain} -t update --check";
  }
  else {
    print 'updating execution...'.PHP_EOL;
    $cmd = "ansible-playbook /etc/ansible/playbooks/docker.yml -e @/etc/ansible/target/{$target}/{$cfg->domain} -t update";
  }
  $ret = shell_exec($cmd);
  $ret = '=updating' . PHP_EOL . '======' . PHP_EOL . $ret . PHP_EOL . '======';
  _log($target, $cfg->domain, $cfg->mount, $ret);
}

function _ping_domain($target, $cfg) {
  $cmd = "curl -IL --request GET http://{$cfg->domain}/user";
  exec($cmd, $ret, $rc);
  if ($rc == 0 && array_search('HTTP/2 200', $ret)) {
    _log($target, $cfg->domain, $cfg->mount, '=ping Success');
  }
  else {
    _log($target, $cfg->domain, $cfg->mount, '=ping Error');
  }
}

function _log($target, $domain, $mount, $result) {
  $log = date('Y-m-d H:i:s') . " - {$target} {$domain} {$mount} {$result}" . PHP_EOL;
  file_put_contents("/var/log/update_container_{$target}_".date('Y-m-d').'.log', $log, FILE_APPEND);
}
