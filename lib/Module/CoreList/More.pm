package Module::CoreList::More;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Module::CoreList ();

sub _firstidx {
    my ($item, $ary) = @_;
    for (0..@$ary-1) {
       return $_ if $ary->[$_] eq $item;
    }
    -1;
}

# construct our own %delta from Module::CoreList's %delta. our version is a
# linear "linked list" (e.g. %delta{5.017} is a delta against %delta{5.016003}
# instead of %delta{5.016}. also, version numbers are cleaned (some versions in
# Module::CoreList has trailing whitespaces or alphas)

# the same for our own %released (version numbers in keys are canonicalized)

our @releases; # list of perl release versions, sorted by version
our @releases_by_date; # list of perl release versions, sorted by release date
our %delta;
our %released;
my %rel_orig_formats;
{
    # first let's only stored the canonical format of release versions
    # (Module::Core stores "5.01" as well as "5.010000"), for less headache
    # let's just store "5.010000"
    my %releases;
    for (sort keys %Module::CoreList::delta) {
        my $canonical = sprintf "%.6f", $_;
        next if $releases{$canonical};
        $releases{$canonical} = $Module::CoreList::delta{$_};
        $released{$canonical} = $Module::CoreList::released{$_};
        $rel_orig_formats{$canonical} = $_;
    }
    @releases = sort keys %releases;
    @releases_by_date = sort {$released{$a} cmp $released{$b}} keys %releases;

    for my $i (0..@releases-1) {
        my $reldelta = $releases{$releases[$i]};
        my $delta_from = $reldelta->{delta_from};
        my $changed = {};
        my $removed = {};
        # make sure that %delta will be linear "linked list" by release versions
        if ($delta_from && $delta_from != $releases[$i-1]) {
            $delta_from = sprintf "%.6f", $delta_from;
            my $i0 = _firstidx($delta_from, \@releases);
            #say "D: delta_from jumps from $delta_from (#$i0) -> $releases[$i] (#$i)";
            # accumulate changes between delta at releases #($i0+1) and #($i-1),
            # subtract them from delta at #($i)
            my $changed_between = {};
            my $removed_between = {};
            for my $j ($i0+1 .. $i-1) {
                my $reldelta_between = $releases{$releases[$j]};
                for (keys %{$reldelta_between->{changed}}) {
                    $changed_between->{$_} = $reldelta_between->{changed}{$_};
                    delete $removed_between->{$_};
                }
                for (keys %{$reldelta_between->{removed}}) {
                    $removed_between->{$_} = $reldelta_between->{removed}{$_};
                }
            }
            for (keys %{$reldelta->{changed}}) {
                next if exists($changed_between->{$_}) &&
                    !defined($changed_between->{$_}) && !defined($reldelta->{changed}{$_}) || # both undef
                    defined ($changed_between->{$_}) && defined ($reldelta->{changed}{$_}) && $changed_between->{$_} eq $reldelta->{changed}{$_}; # both defined & equal
                $changed->{$_} = $reldelta->{changed}{$_};
            }
            for (keys %{$reldelta->{removed}}) {
                next if $removed_between->{$_};
                $removed->{$_} = $reldelta->{removed}{$_};
            }
        } else {
            $changed = { %{$reldelta->{changed}} };
            $removed = { %{$reldelta->{removed} // {}} };
        }

        # clean version numbers
        for my $k (keys %$changed) {
            for ($changed->{$k}) {
                next unless defined;
                s/\s+$//; # eliminate trailing space
                # for "alpha" version, turn trailing junk such as letters to _
                # plus a number based on the first junk char
                s/([^.0-9_])[^.0-9_]*$/'_'.sprintf('%03d',ord $1)/e;
            }
        }
        $delta{$releases[$i]} = {
            changed => $changed,
            removed => $removed,
        };
    }
}

my $removed_from = sub {
    my ($order, $module) = splice @_,0,2;
    $module = shift if eval { $module->isa(__PACKAGE__) } && @_ > 0 && defined($_[0]) && $_[0] =~ /^\w/;

    my $ans;
    for my $rel ($order eq 'date' ? @releases_by_date : @releases) {
        my $delta = $delta{$rel};
        if ($delta->{removed}{$module}) {
            $ans = $rel_orig_formats{$rel};
            last;
        }
    }

    return wantarray ? ($ans ? ($ans) : ()) : $ans;
};

sub removed_from {
    $removed_from->('', @_);
}

sub removed_from_by_date {
    $removed_from->('date', @_);
}

my $first_release = sub {
    my ($order, $module) = splice @_,0,2;
    $module = shift if eval { $module->isa(__PACKAGE__) } && @_ > 0 && defined($_[0]) && $_[0] =~ /^\w/;

    my $ans;
    for my $rel ($order eq 'date' ? @releases_by_date : @releases) {
        my $delta = $delta{$rel};
        if (exists $delta->{changed}{$module}) {
            $ans = $rel_orig_formats{$rel};
            last;
        }
    }

    return wantarray ? ($ans ? ($ans) : ()) : $ans;
};

sub first_release {
    $first_release->('', @_);
}

sub first_release_by_date {
    $first_release->('date', @_);
}

my $is_core = sub {
    my $all = pop;
    my $module = shift;
    $module = shift if eval { $module->isa(__PACKAGE__) } && @_ > 0 && defined($_[0]) && $_[0] =~ /^\w/;
    my ($module_version, $perl_version);

    $module_version = shift if @_ > 0;
    $perl_version   = @_ > 0 ? shift : $];

    my $mod_exists = 0;
    my $mod_ver; # module version at each perl release, -1 means doesn't exist

  RELEASE:
    for my $rel (sort keys %delta) {
        last if $all && $rel > $perl_version; # this is the difference with is_still_core()

        my $reldelta = $delta{$rel};

        if ($rel > $perl_version) {
            if ($reldelta->{removed}{$module}) {
                $mod_exists = 0;
            } else {
                next;
            }
        }

        if (exists $reldelta->{changed}{$module}) {
            $mod_exists = 1;
            $mod_ver = $reldelta->{changed}{$module};
        } elsif ($reldelta->{removed}{$module}) {
            $mod_exists = 0;
        }
    }

    if ($mod_exists) {
        if (defined $module_version) {
            return 0 unless defined $mod_ver;
            return version->parse($mod_ver) >= version->parse($module_version) ? 1:0;
        }
        return 1;
    }
    return 0;
};

sub is_core { $is_core->(@_,1) }

sub is_still_core { $is_core->(@_,0) }

my $list_core_modules = sub {
    my $all = pop;
    my $class = shift if @_ && eval { $_[0]->isa(__PACKAGE__) };
    my $perl_version = @_ ? shift : $];

    my %added;
    my %removed;

  RELEASE:
    for my $rel (sort keys %delta) {
        last if $all && $rel > $perl_version; # this is the difference with list_still_core_modules()

        my $delta = $delta{$rel};

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
};

sub list_core_modules { $list_core_modules->(@_,1) }

sub list_still_core_modules { $list_core_modules->(@_,0) }

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

=head2 first_release( MODULE )

Like Module::CoreList's version, but faster (see L</"BENCHMARK">).

=head2 first_release_by_date( MODULE )

Like Module::CoreList's version, but faster (see L</"BENCHMARK">).

=head2 removed_from( MODULE )

Like Module::CoreList's version, but faster (see L</"BENCHMARK">).

=head2 removed_from_by_date( MODULE )

Like Module::CoreList's version, but faster (see L</"BENCHMARK">).

=head2 is_core( MODULE, [ MODULE_VERSION, [ PERL_VERSION ] ] )

Like Module::CoreList's version, but faster (see L</"BENCHMARK">).

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
