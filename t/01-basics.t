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

subtest list_still_core_modules => sub {
    my %mods5010000 = Module::CoreList::More->list_still_core_modules(5.010);
    my %mods5010001 = Module::CoreList::More->list_still_core_modules(5.010001);
    my %mods5018000 = Module::CoreList::More->list_still_core_modules(5.018000);

    is( $mods5010000{'Benchmark'}, 1.1);
    is( $mods5010001{'Benchmark'}, 1.11);
    is( $mods5018000{'Benchmark'}, 1.15);

    ok(!$mods5010000{'parent'});
    is( $mods5010001{'parent'}, 0.221);
    is( $mods5018000{'parent'}, 0.225);

    ok(!$mods5010000{'CGI'});
    ok(!$mods5010001{'CGI'});
    ok(!$mods5018000{'CGI'});
};

DONE_TESTING:
done_testing;
