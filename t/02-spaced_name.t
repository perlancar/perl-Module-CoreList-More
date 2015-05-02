#!perl

use 5.010;
use strict;

use Module::CoreList;
use Module::CoreList::More;
use Test::More 0.98;

subtest spaced_version_no_warns => sub {
  local $SIG{__WARN__} = sub { die $_[0] };
  ok eval { Module::CoreList::More->is_core('CPAN::FirstTime',1) };
};

DONE_TESTING:
done_testing;
