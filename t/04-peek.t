use Test;
use Archive::Tar::PP;

plan 33;

sub full-dir(IO $path) {
  ($path.dir.map({ $_ ~~ :d ?? full-dir($_).Slip !! $_.relative }).Slip, $path.relative~'/').Slip;
}

my @ftar = full-dir './t/perl6-archive-tar-pp-master/'.IO; #old disgusting cp from master
my @elems;

my $reader = read-tar('./t/tar/git.tar');
@elems = $reader.ls;
ok @elems.elems == @ftar.elems, 'git.tar has same number of files as our extracted using `tar`';
for @elems -> $e {
  ok @ftar.grep(* ~~ / $e $$ /), "matched: {$e.chars > 40 ?? "... {$e.substr(*-40,40)}" !! $e}";
}

my $tmp-file = "{$*TMPDIR.absolute}/{('a'..'z').pick(20).join('')}".IO;
my $writer = new-tar($tmp-file);

$writer.push(@ftar);
$writer.write;

ok True, 'writer completed succesfully';
@elems = read-tar($tmp-file).ls;
ok read-tar($tmp-file).ls.elems == @ftar, 'file count matches between git tar and our created tmp tar';
for @elems -> $e {
  ok @ftar.grep(* ~~ / $e $$ /), "matched: {$e.chars > 40 ?? "... {$e.substr(*-40,40)}" !! $e}";
}

try $tmp-file.unlink;

# vim:syntax=perl6
