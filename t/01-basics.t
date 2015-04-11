#!perl

use 5.010;
use strict;
use warnings;

use Module::CoreList::More;
use Test::More 0.98;

subtest is_still_core => sub {
    # always in core
    ok(Module::CoreList::More->is_still_core("Benchmark"));

    # never in core
    ok(!Module::CoreList::More->is_still_core("Module::Path"));

    # not yet core
    ok(!Module::CoreList::More->is_still_core("IO::Socket::IP", undef, 5.010001));

    # removed
    ok(!Module::CoreList::More->is_still_core("CGI"));


    # call as function
    ok(Module::CoreList::More::is_still_core("Benchmark"));

    # arg: module_version
    ok(!Module::CoreList::More->is_still_core("Benchmark", 9.99));

    # arg: perl_version
    ok( Module::CoreList::More->is_still_core("IO::Socket::IP", undef, 5.020000));
    ok(!Module::CoreList::More->is_still_core("IO::Socket::IP", undef, 5.010000));
};

DONE_TESTING:
done_testing;
