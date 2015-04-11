package Module::CoreList::More;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Module::CoreList;

sub is_still_core {
    my $module = shift;
    $module = shift if eval { $module->isa(__PACKAGE__) } && @_ > 0 && defined($_[0]) && $_[0] =~ /^\w/;
    my ($module_version, $perl_version);

    $module_version = shift if @_ > 0;
    $perl_version   = @_ > 0 ? shift : $];

    my $first_rel; # first perl version where module is in core

  RELEASE:
    for my $rel (sort keys %Module::CoreList::delta) {
        my $delta = $Module::CoreList::delta{$rel};
        if ($first_rel) {
            # we have found the first release where module is included, check if
            # module is removed
            return 0 if $delta->{removed}{$module};
        } else {
            # we haven't found the first release where module is included
            if (exists $delta->{changed}{$module}) {
                my $modver = $delta->{changed}{$module};
                if (defined $module_version) {
                    if (version->parse($modver) >= version->parse($module_version)) {
                        $first_rel = $rel;
                    }
                } else {
                    $first_rel = $rel;
                }
                if ($first_rel) {
                    return 0 if $first_rel > $perl_version;
                }
            }
        }
    }

    # module has been included and never removed
    return 1 if $first_rel;

    # we never found the first release where module is first included
    0;
}

1;

# ABSTRACT: More functions for Module::CoreList

=head1 SYNOPSIS

 use Module::CoreList::More;

 # return false, since CGI is removed in perl 5.021000
 Module::CoreList::More->is_still_core("CGI");


=head1 DESCRIPTION

This module is my experiment for providing more functionality to (or related to)
L<Module::CoreList>. Some ideas include: faster functions (for some use-cases),
more querying functions, more convenience functions. When I've got something
stable and useful to show for, I'll most probably suggest the appropriate
additions to Module::CoreList.

Below are random notes:

C<is_core()> is slow (+- 700/s on my office PC), I used to have a problem with
this, but forgot where and I got a workaround anyway. We can speed things up
e.g. by producing a cached data structure of list of core modules for a certain
Perl release (the data structure in Module::CoreList are just list of Perl
releases + date %released and %delta which only lists differences of modules
between Perl releases).


=head1 FUNCTIONS

These functions are not exported. They can be called as function (e.g.
C<Module::CoreList::More::is_still_core($name)> or as class method (e.g. C<<
Module::CoreList::More->is_still_core($name) >>.

=head1 is_still_core( MODULE, [ MODULE_VERSION, [ PERL_VERSION ] ] )

Like C<is_core>, but will also check that from PERL_VERSION up to the latest
known version, MODULE has never been removed from core.

Note/idea: could also be implemented by adding a fourth argument
MAX_PERL_VERSION to C<is_core>, defaulting to the latest known version.


=head1 SEE ALSO

L<Module::CoreList>
