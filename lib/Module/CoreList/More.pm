package Module::CoreList::More;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Module::CoreList;

sub is_core {
    my $module = shift;
    $module = shift if eval { $module->isa(__PACKAGE__) } && @_ > 0 && defined($_[0]) && $_[0] =~ /^\w/;
    my ($module_version, $perl_version);

    $module_version = shift if @_ > 0;
    $perl_version   = @_ > 0 ? shift : $];

    my $first_rel; # first perl version where module is in core

  RELEASE:
    for my $rel (sort keys %Module::CoreList::delta) {
        last if $rel > $perl_version; # this is the difference with is_still_core()

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

sub list_core_modules {
    my $class = shift if @_ && eval { $_[0]->isa(__PACKAGE__) };
    my $perl_version = @_ ? shift : $];

    my %added;
    my %removed;

  RELEASE:
    for my $rel (sort keys %Module::CoreList::delta) {
        last if $rel > $perl_version; # this is the difference with list_still_core_modules()

        my $delta = $Module::CoreList::delta{$rel};

        next unless $delta->{changed};
        for my $mod (keys %{$delta->{changed}}) {
            # module has been removed between perl_version..latest, skip
            next if $removed{$mod};

            if (exists $added{$mod}) {
                # module has been added in a previous version, update first
                # version
                $added{$mod} = $delta->{changed}{$mod} if $rel <= $perl_version;
            } else {
                # module is first added after perl_version, skip
                next if $rel > $perl_version;

                $added{$mod} = $delta->{changed}{$mod};
            }
        }
        next unless $delta->{removed};
        for my $mod (keys %{$delta->{removed}}) {
            delete $added{$mod};
            # module has been removed between perl_version..latest, mark it
            $removed{$mod}++ if $rel >= $perl_version;
        }

    }
    %added;
}

sub list_still_core_modules {
    my $class = shift if @_ && eval { $_[0]->isa(__PACKAGE__) };
    my $perl_version = @_ ? shift : $];

    my %added;
    my %removed;

  RELEASE:
    for my $rel (sort keys %Module::CoreList::delta) {
        my $delta = $Module::CoreList::delta{$rel};

        next unless $delta->{changed};
        for my $mod (keys %{$delta->{changed}}) {
            # module has been removed between perl_version..latest, skip
            next if $removed{$mod};

            if (exists $added{$mod}) {
                # module has been added in a previous version, update first
                # version
                $added{$mod} = $delta->{changed}{$mod} if $rel <= $perl_version;
            } else {
                # module is first added after perl_version, skip
                next if $rel > $perl_version;

                $added{$mod} = $delta->{changed}{$mod};
            }
        }
        next unless $delta->{removed};
        for my $mod (keys %{$delta->{removed}}) {
            delete $added{$mod};
            # module has been removed between perl_version..latest, mark it
            $removed{$mod}++ if $rel >= $perl_version;
        }

    }
    %added;
}

1;

# ABSTRACT: More functions for Module::CoreList

=head1 SYNOPSIS

 use Module::CoreList::More;

 # true, this module has always been in core since specified perl release
 Module::CoreList::More->is_still_core("Benchmark", 5.010001);

 # false, since CGI is removed in perl 5.021000
 Module::CoreList::More->is_still_core("CGI");

 # false, never been in core
 Module::CoreList::More->is_still_core("Foo");

 my %modules = list_still_core_modules(5.010001);


=head1 DESCRIPTION

This module is my experiment for providing more functionality to (or related to)
L<Module::CoreList>. Some ideas include: faster functions, more querying
functions, more convenience functions. When I've got something stable and useful
to show for, I'll most probably suggest the appropriate additions to
Module::CoreList.

Below are random notes:


=head1 FUNCTIONS

These functions are not exported. They can be called as function (e.g.
C<Module::CoreList::More::is_still_core($name)> or as class method (e.g. C<<
Module::CoreList::More->is_still_core($name) >>.

=head2 is_core( MODULE, [ MODULE_VERSION, [ PERL_VERSION ] ] )

Like Module::CoreList's C<is_core>, but faster (see L</"BENCHMARK">).
Module::CoreList's C<is_core()> is in general unoptimized, so our version can be
much faster.

Ideas for further speeding up (if needed): produce a cached data structure of
list of core modules for a certain Perl release (the data structure in
Module::CoreList are just list of Perl releases + date %released and %delta
which only lists differences of modules between Perl releases).

=head2 is_still_core( MODULE, [ MODULE_VERSION, [ PERL_VERSION ] ] )

Like C<is_core>, but will also check that from PERL_VERSION up to the latest
known version, MODULE has never been removed from core.

Note/idea: could also be implemented by adding a fourth argument
MAX_PERL_VERSION to C<is_core>, defaulting to the latest known version.

=head2 list_core_modules([ PERL_VERSION ]) => %modules

List modules that are in core at specified perl release.

=head2 list_still_core_modules([ PERL_VERSION ]) => %modules

List modules that are (still) in core from specified perl release to the latest.
Keys are module names, while values are versions of said modules in specified
perl release.


=head1 BENCHMARK

#COMMAND: devscripts/bench


=head1 SEE ALSO

L<Module::CoreList>
