use lib 'lib';
use Archive::Tar::PP;

my $a = tar('test.tar');

$a.push('x.pl6');

$a.write;
