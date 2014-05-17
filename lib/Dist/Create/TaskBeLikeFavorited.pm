package Dist::Create::TaskBeLikeFavorited;

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
use Log::Any '$log';

use File::chdir;
use File::Slurp::Tiny qw(read_file write_file);
use LWP::Simple;
use Mojo::DOM;
use POSIX qw(strftime);

our $VERSION = '0.04'; # VERSION

our %SPEC;

sub _list_favorited_modules {
    my ($cpanid) = @_;

    my $url  = "https://metacpan.org/author/$cpanid";
    $log->infof("Getting %s ...", $url);
    my $page = get $url;
    die "Can't get $url" unless $page;
    my $dom = Mojo::DOM->new($page);

    my @res;
    for ($dom->find("table.release-table:last-of-type td.release")->each) {
        push @res, $1 if m!"/release/(.+?)"!;
    }

    # for speed, currently we haven't bothered to check
    # http://metacpan.org/release/$DIST . we actually need to do this because:
    # 1) some dists do not have module of the same name, e.g. libwww-perl
    # (currently we provide a hard-coded list); 2) some dists have been deleted,
    # but still show up in favorited list (probably a metacpan.org bug?)

    my @skipped = qw(
                        perl
                        Marpa
                );

    @res = grep {!($_ ~~ @skipped)} @res;

    my %dist2mod = (
        "libwww-perl" => "LWP",
        "cpan-listchanges" => "App::cpanlistchanges",
    );

    for (@res) {
        if ($dist2mod{$_}) {
            $_ = $dist2mod{$_};
        } else {
            s/-/::/g;
        }
    }

    $log->tracef("Got modules: %s", \@res);
    @res;
}

$SPEC{create_task_belike_favorited_dist} = {
    v           => 1.1,
    summary     => 'Create Task-BeLike-$AUTHOR-Favorited distribution',
    args        => {
        cpan_id => {
            schema => 'str*',
            req    => 1,
            pos    => 0,
        },
        target_dir => {
            schema => 'str*',
            summary => 'Target distribution directory',
            description => <<'_',

Defaults to ./Task-BeLike-$AUTHOR-Favorited

_
        },
    },
    deps => {
    },
};
sub create_task_belike_favorited_dist {
    my %args = @_;

    # TMP, schema
    my $cpanid = $args{cpan_id} or return [400, "Please specify cpan_id"];
    $cpanid =~ /\A\w+\z/ or return [400, "Invalid cpan_id"];
    $cpanid = uc($cpanid);

    my $dir = $args{target_dir} // "Task-BeLike-$cpanid-Favorited";

    use autodie;
    mkdir $dir;
    local $CWD = $dir;
    write_file(".gitignore", "Task-BeLike-$cpanid-Favorited-*\n.build\n*~\n");
    write_file("Changes", <<_);
Revision history for Task-BeLike-$cpanid-Favorited
_
    write_file("MANIFEST.SKIP", '~$');
    write_file("dist.ini", <<_);
version = 0.00

name    = Task-BeLike-$cpanid-Favorited
author  = $cpanid <$cpanid\@cpan.org>
license = Perl_5
;copyright_holder = $cpanid

[MetaResources]
homepage    = http://metacpan.org/release/Task-BeLike-$cpanid-Favorited
;repository  = http://github.com/$cpanid/perl-Task-BeLike-$cpanid-Favorited

[\@SHARYANTO::Task]
_

    mkdir "t";
    write_file("t/.exists", "");

    mkdir "lib";
    mkdir "lib/Task";
    mkdir "lib/Task/BeLike";
    mkdir "lib/Task/BeLike/$cpanid";
    my $comment = "#"; # to prevent podweaver from being fooled
    my $pod = "="; # ditto
    # split package + PKG to work around false positive of DZP::Rinci::Validate
    write_file("lib/Task/BeLike/$cpanid/Favorited.pm", "package " . <<_);
Task::BeLike::$cpanid\::Favorited;

# VERSION

1;
$comment ABSTRACT: Install all $cpanid\'s favorite modules

${pod}head1 DESCRIPTION

This task will install modules favorited by $cpanid on L<http://metacpan.org>.

${pod}pkgroup Included modules

${pod}cut
_
    update_task_belike_favorited_dist();
}

$SPEC{update_task_belike_favorited_dist} = {
    v           => 1.1,
    summary     => 'Update Task-BeLike-$AUTHOR-Favorited distribution',
    args        => {
    },
    deps => {
    },
};
sub update_task_belike_favorited_dist {
    my %args = @_;

    my ($pm) = <lib/Task/BeLike/*/Favorited.pm>;

    (-f "dist.ini") or return [412, "Can't find dist.ini in current directory"];
    (-f "Changes") or return [412, "Can't find Changes in current directory"];
    (-f $pm) or return [412,"Can't find lib/Task/BeLike/\$AUTHOR/Favorited.pm"];

    my ($cpanid) = $pm =~ m!BeLike/([^/]+)!;

    # update list of modules in pm
    my @mods = _list_favorited_modules($cpanid);
    my $perl = read_file($pm);
    $perl =~ s/^(=pkgroup [^\n]+).+(^=cut)/
        $1 . "\n\n" . join("", map {"=pkg $_\n\n"} @mods). $2/mse
            or return [500, "Can't find =pkgroup in $pm"];
    write_file($pm, $perl);

    # increase version in dist.ini
    my $ini = read_file("dist.ini");
    my ($v) = $ini =~ /^\s*version\s*=\s*(.+)/m;
    defined($v) or return [500, "Can't find version in dist.ini"];
    $v += 0.01;
    $ini =~ s/^\s*version\s*=\s*(.+)/version = $v/m;
    write_file("dist.ini", $ini);

    # add an entry to Changes
    my $date = strftime("%Y-%m-%d", localtime);
    my $summary = "- Update list of modules (done by $0 version ".
        ($Dist::Create::TaskBeLikeFavorited::VERSION // "?").")";
    write_file("Changes", {append=>1},
               sprintf("\n%-8.2f%s\n        %s\n",
                       $v, $date, $summary));

    [200, "OK"];
}

1;
# ABSTRACT: Create your own Task-BeLike-$AUTHOR-Favorited distribution

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Create::TaskBeLikeFavorited - Create your own Task-BeLike-$AUTHOR-Favorited distribution

=head1 VERSION

This document describes version 0.04 of Dist::Create::TaskBeLikeFavorited (from Perl distribution Dist-Create-TaskBeLikeFavorited), released on 2014-05-17.

=head1 SYNOPSIS

To create and upload your dist to CPAN:

 % create-task-belike-favorited-dist SHARYANTO
 % cd Task-BeLike-SHARYANTO-Favorited
 % # you'll probably want to edit dist.ini first to tweak stuffs
 % dzil release

To update your dist and release to CPAN:

 % cd Task-BeLike-SHARYANTO-Favorited
 % update-task-belike-favorited-dist
 % dzil release

=head1 DESCRIPTION

C<Task::BeLike::$AUTHOR::Favorited> tasks contain modules that have been
favorited by $AUTHOR (by clicking the C<++> button) on L<http://metacpan.org>.
This module creates distributions that contain such tasks.

The created distributions currently require L<Dist::Zilla> and
L<Dist::Zilla::PluginBundle::SHARYANTO> to be built.

=head1 FUNCTIONS


=head2 create_task_belike_favorited_dist(%args) -> [status, msg, result, meta]

Create Task-BeLike-$AUTHOR-Favorited distribution.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cpan_id>* => I<str>

=item * B<target_dir> => I<str>

Target distribution directory.

Defaults to ./Task-BeLike-$AUTHOR-Favorited

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.


=head2 update_task_belike_favorited_dist() -> [status, msg, result, meta]

Update Task-BeLike-$AUTHOR-Favorited distribution.

No arguments.

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

=head1 FAQ

=head2 Why?

Mostly so you can do something like:

 % cpanm -n Task::BeLike::YOU::Favorited

on a fresh system and conveniently have all your favorite modules installed.

Of course, you'll have to build and upload your task distribution to CPAN first
(see Synopsis).

=head2 But you can simply do something simpler like this instead ...

 % cpan_favorites() {
   perl -Mojo -E "g('https://metacpan.org/author/$1')->dom('td.release a')->pluck('text')->each(sub{s/-/::/g;say})"
   }
 % cpan_favorites SHARYANTO | cpanm -n

True. Creating a task distribution on CPAN is definitely more work. However,
creating a task distribution has several pro's: 1) it works offline if you
mirror CPAN; 2) it lets you track your favorites over time by comparing past
versions of the task.

=head1 SEE ALSO

http://blogs.perl.org/users/dpetrov/2012/11/install-all-metacpan-favorited-distributions.html

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Dist-Create-TaskBeLikeFavorited>.

=head1 SOURCE

Source repository is at L<https://github.com/sharyanto/perl-Dist-Create-TaskBeLikeFavorited>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Create-TaskBeLikeFavorited>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
