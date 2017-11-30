# usage

since i know this is all you care about

```perl6
use Archive::Tar::PP;

my $new-archive = tar('x.tar'.IO);

$x.allocate-buffer('some file'.IO); #adds file data to buffer;

$x.write;
```

# limitations

* handles a path and directory paxheaders (not extended)
* doesn't keep user or group names
* cannot read tars _yet_
* stores the buffers in memory so, beware
