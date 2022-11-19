<?php

$in     = file($argv[1]);
$mem    = [];
$entry  = 0;

$bin_file = '';
$hex_file = '';
$mif_file = '';

$font = file_get_contents(__DIR__ . '/font.bin');

foreach ($argv as $val) {

    if (preg_match('~bin=(.+)~', $val, $c)) $bin_file = $c[1];
    if (preg_match('~mif=(.+)~', $val, $c)) $mif_file = $c[1];
    if (preg_match('~hex=(.+)~', $val, $c)) $hex_file = $c[1];
}

// Парсер LST файла
foreach ($in as $row) {

    if (preg_match('~^([0-9a-z]+)\s+\d+\s+(.+)~i', $row, $c)) {

        $ex = explode(" ", $c[2]);
        $id = hexdec($c[1]);

        if (preg_match('~.segment.+CODE~i', $row)) {
            $entry = $id;
        }

        foreach ($ex as $i => $b) {
            if (preg_match('~^[0-9a-z]{2}$~i', $b)) {
                $mem[$id + $i] = hexdec($b);
            } else {
                break;
            }
        }
    }
}

// RESET Entry
$mem[0xFFFC] =  $entry & 255;
$mem[0xFFFD] = ($entry >> 8) & 255;

$res = '';
$hex = '';

for ($i = 0; $i < 65536; $i++) {

    $mem[$i] = $mem[$i] ?? 0;

    // Загрузка шрифтов
    if ($i >= 0x3000 && $i < 0x4000) $mem[$i] = ord($font[$i - 0x3000]);

    $res .= chr($mem[$i]);
    $hex .= sprintf("%02x\n", $mem[$i]);
}

if ($bin_file) file_put_contents($bin_file, $res);

// ---------------------------------------------------------------------

$a    = 0;
$len  = 65536;
$out  = "WIDTH=8;\nDEPTH=65536;\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n";

// RLE-кодирование
while ($a < $len) {

    // Поиск однотонных блоков
    for ($b = $a + 1; $b < $len && $mem[$a] == $mem[$b]; $b++);

    // Если найденный блок длиной до 0 до 2 одинаковых символов
    if ($b - $a < 3) {
        for ($i = $a; $i < $b; $i++) $out .= sprintf("  %x: %02x;\n", $a++, $mem[$i]);
    } else {
        $out .= sprintf("  [%x..%x]: %02x;\n", $a, $b-1, $mem[$a]);
        $a = $b;
    }
}

$out .= "END;";

if ($mif_file) file_put_contents($mif_file, $out);
if ($hex_file) file_put_contents($hex_file, $hex);
