use Test;
use Archive::Tar::PP;

plan 5;

my $pax-fn = 'T0NFt4Seh3mnYaF3a7fMxTZVtPyKIrk67qrW2yD7C49L8zJwL9CUnWE75bUWgMovlIU3F1g4WbjS7KiIsrvqThZAIrkvQB2tqI0y6yRpRG8qqW';
my @elems;

my $reader = read-tar('./t/tar/pax.tar');
@elems = $reader.ls;
ok @elems.elems == 1, 'pax.tar has only one file';
ok @elems[0] eq $pax-fn, 'pax.tar has our really long file name';

my $tmp-file = "{$*TMPDIR.absolute}/{('a'..'z').pick(20).join('')}".IO;
my $writer = new-tar($tmp-file);

$writer.push("./t/pax/$pax-fn");
$writer.write;

ok True, 'writer completed succesfully';
@elems = read-tar($tmp-file).ls;
ok read-tar($tmp-file).ls.elems == 1, 'created tmp file has our pax file';
ok read-tar($tmp-file).ls[0] ~~ /$pax-fn $$/, 'created tmp file filename matches ours';

try $tmp-file.unlink;

# vim:syntax=perl6
