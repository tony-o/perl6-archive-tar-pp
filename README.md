# usage

since i know this is all you care about

## new tar
```perl6
use Archive::Tar::PP;

my $new-archive = new-tar('x.tar');

$new-archive.push('some file'); #adds file data to buffer;

$new-archive.write; #now you have some tarball
```

## crusty tar
```perl6
use Archive::Tar::PP;

my $crusty = read-tar('x.tar');

$crusty.ls; #returns files
```

# limitations

* doesn't keep user or group names
* stores the buffers in memory so, beware
* rewrites entire tar file every time you write, so use sparingly
