use lib 'lib';
use Archive::Tar::PP;

my $a = tar('test.tar');

use Archive::Tar::PP::Util;
read-tar('test/pax.tar'.IO);

#$a.push('x.pl6');

#$a.write;
