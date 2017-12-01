use Test;
use Archive::Tar::PP;

plan 18;

sub full-dir(IO $path) {
  ($path.dir.map({ $_ ~~ :d ?? full-dir($_).Slip !! $_.relative }).Slip, $path.relative~'/').Slip;
}

my @ftar = full-dir './t/perl6-archive-tar-pp-master/'.IO; #old disgusting cp from master
my @elems;

my $reader = read-tar('./t/tar/git.tar');
@elems = $reader.ls;
my $peek;
for @elems -> $e {
  $peek = $reader.peek($e);
  is-deeply $peek.value, Buf.new(@ftar.grep(* ~~ / $e $$/)[0].IO.slurp(:bin)), "{$e.IO.basename.chars > 40 ?? $e.IO.basename.substr(0,37)~'..' !! $e.IO.basename} contents same same"
    if $peek.key ne 'd';
}

my $tmp-file = "{$*TMPDIR.absolute}/{('a'..'z').pick(20).join('')}".IO;
my $writer = new-tar($tmp-file);

$writer.push(@ftar);
$writer.write;

$reader = read-tar($tmp-file);

@elems = $reader.ls;
for @elems -> $e {
  $peek = $reader.peek($e);
  is-deeply $peek.value, Buf.new(@ftar.grep(* ~~ / $e $$/)[0].IO.slurp(:bin)), "{$e.IO.basename.chars > 40 ?? $e.IO.basename.substr(0,37)~'..' !! $e.IO.basename} contents same same"
    if $peek.key ne 'd';
}

try $tmp-file.unlink;

# vim:syntax=perl6
