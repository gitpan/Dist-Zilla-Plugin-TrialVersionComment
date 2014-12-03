use strict;
use warnings;
package Dist::Zilla::Plugin::TrialVersionComment;
# git description: v0.002-1-g506e5e1
$Dist::Zilla::Plugin::TrialVersionComment::VERSION = '0.003';
# ABSTRACT: Add a # TRIAL comment after your version declaration in trial # releases
# KEYWORDS: plugin modules package version comment trial release
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with
    'Dist::Zilla::Role::PPI',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' =>
        { default_finders => [ ':InstallModules', ':ExecFiles' ] },
;
use Module::Runtime 'module_notional_filename';
use namespace::autoclean;

sub munge_files
{
    my $self = shift;

    $self->log_debug([ 'release_status is not trial; doing nothing' ]), return
        if not $self->zilla->is_trial;

    foreach my $file ( @{ $self->found_files })
    {
        next if $file->can('is_bytes') and $file->is_bytes;
        next if $INC{module_notional_filename('Dist::Zilla::Role::MutableFile')} and not $file->does('Dist::Zilla::Role::MutableFile');

        # it would be nice if we could just ask Module::Metadata for the line
        # (and character offset!) that it already found - might be faster

        my $document = $self->ppi_document_for_file($file);

        my $package_stmt = $document->find_first('PPI::Statement::Package');
        $self->log_debug([ 'skipping %s: no package statement found', $file->name ]), return
            if not $package_stmt;

        my %seen_version_for_package;
        my $package = 'main';

        my $munged = 0;

        my $finder = sub {
            my $node = $_[1];
            return 0 if not $node->isa('PPI::Statement');

            # this does not properly handle scopes - see the ::Package docs
            $package = $node->namespace, return undef if $node->isa('PPI::Statement::Package');

            # do not descend into the nodes comprising the statement
            return undef unless $node->isa('PPI::Statement::Variable')
                and $node->type eq 'our'
                and grep { $_ eq '$VERSION' } $node->variables;

            # find the line with this statement - this is safe to do even
            # after munging because we do not insert or remove lines
            my @content_lines = split("\n", $file->content, $node->line_number + 1);
            return $content_lines[$#content_lines - 1] !~ /;\h*#\s*TRIAL/;   # no existing comment on line
        };

        my $matches = $document->find($finder);
        if (not $matches)
        {
            $self->log_fatal('got PPI error') if not defined $matches;
            next;
        }

        foreach my $node (@{ $matches })
        {
            $self->log_debug([ 'Adding # TRIAL to $VERSION line for %s', $package ]);

            # inserted in reverse order... can I insert both at the same time?
            $node->insert_after(PPI::Token::Comment->new('# TRIAL'));
            $node->insert_after(PPI::Token::Whitespace->new(' '));
            $document->flush_locations;
            $munged = 1;
        }

        $self->save_ppi_document_to_file($document, $file) if $munged;
    }
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::TrialVersionComment - Add a # TRIAL comment after your version declaration in trial # releases

=head1 VERSION

version 0.003

=head1 SYNOPSIS

In your F<dist.ini>:

    [TrialVersionComment]

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin that munges your F<.pm> files to add a
C<# TRIAL> comment after C<$VERSION> assignments, if the release is C<--trial>.

If the distribution is not a C<--trial> release (i.e. C<release_status> in
metadata is C<stable>), this plugin does nothing.

=for stopwords PkgVersion OurPkgVersion RewriteVersion

Other plugins that munge versions into files also add the C<# TRIAL> comment (such as
L<[PkgVersion]|Dist::Zilla::Plugin::PkgVersion>,
L<[OurPkgVersion]|Dist::Zilla::Plugin::OurPkgVersion>, and
L<[RewriteVersion]|Dist::Zilla::Plugin::RewriteVersion>, so you would
generally only need this plugin if you added the version yourself, manually.

Nothing currently parses these comments, but the idea is that things like
L<Module::Metadata> might make use of this in the future.

=for Pod::Coverage munge_files

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-TrialVersionComment>
(or L<bug-Dist-Zilla-Plugin-TrialVersionComment@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-TrialVersionComment@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 ACKNOWLEDGEMENTS

=for stopwords xdg

Inspiration for this module came about through multiple toolchain conversations with David Golden (xdg).

=head1 SEE ALSO

=for stopwords BumpVersionAfterRelease
OverridePkgVersion
PkgVersionIfModuleWithPod
SurgicalPkgVersion

=over 4

=item *

L<[PkgVersion]|Dist::Zilla::Plugin::PkgVersion>

=item *

L<[OurPkgVersion]|Dist::Zilla::Plugin::OurPkgVersion>

=item *

L<[BumpVersionAfterRelease]|Dist::Zilla::Plugin::BumpVersionAfterRelease>

=item *

L<[OverridePkgVersion]|Dist::Zilla::Plugin::OverridePkgVersion>

=item *

L<[SurgicalPkgVersion]|Dist::Zilla::Plugin::SurgicalPkgVersion>

=item *

L<[PkgVersionIfModuleWithPod]|Dist::Zilla::Plugin::PkgVersionIfModuleWithPod>

=back

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
