#!/usr/bin/perl

package Bookmarks::Netscape;
use Bookmarks::Parser;
use base 'Bookmarks::Parser';
use warnings;
use HTML::TreeBuilder;
use Data::Dumper;

my %bookmark_fields = (
  'created'       => 'add_date',
  'modified'      => 'last_modified',
  'visited'       => 'last_visit',
  'charset'       => 'last_charset',
  'url'           => 'href',
  'name'          => 'content',
  'id'            => 'id',
  'personal'      => 'personal_toolbar_folder',
  'icon'          => 'icon',
  'description'   => undef,
  'expanded'      => undef,
  'panel'         => 'web_panel',
                       );

sub new
{
    my ($class, %opts) = @_;
    %opts = check_options(%opts);

    my $self = bless({%opts}, ref($class) || $class);
    return $self; 
}

sub check_options
{
    my %opts = @_;
    return %opts;
}

sub parse_file
{
    my ($self, $filename) = @_;

    return undef if(!-e $filename);

    my $bookmarks = HTML::TreeBuilder->new();
    $bookmarks->parse_file($filename);

#    $bookmarks->dump();    

    my $title = $bookmarks->look_down(_tag => 'title')->as_text();
    $self->set_title($title);

    my @items = $bookmarks->look_down(sub { $_[0]->tag =~ /^(h3|a)$/ &&
                                            $_[0]->depth == 4 } );
    foreach my $item (@items)
    {
        _parse_item($self, $item);
    }

    $bookmarks->delete();
    return $self;

#    print Dumper($self);
}

sub _parse_item
{
    my ($self, $item, $parent) = @_;

    my %item_info;
    @item_info{keys %bookmark_fields}
      = (map {$item->attr($_)} values %bookmark_fields);
    $item_info{name} = $item->content()->[0];
#    $item_info{parent} = $parent;
    if(!$item_info{id})
    {
        $item_info{id} = $self->{_nextid}++;
    }
    if($item->attr('href'))
    {
       $item_info{type} = 'url';
    }
    else
    {
       $item_info{type} = 'folder';
       if(lc $item->parent->right() && $item->parent->right->tag() eq 'dd')
       {
           $item_info{description} = $item->parent->right->as_text();
           $item = $item->parent->right();
       }
    }

    $self->add_bookmark(\%item_info, $parent);

    if($item_info{type} eq 'folder')
    {
#        $item->dump;
#        $item->right->dump;
       my @subitems = map { $_->tag() eq 'dt' ? ($_->content_list)[0] : () } 
          $item->right->content_list();
       foreach my $subitem (@subitems)
       {
           _parse_item($self, $subitem, $item_info{id});
       }
    }
#    print Dumper(\%item_info);
}

sub get_header_as_string
{
    my ($self) = @_;

    my $header = << "HTML";
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
It will be read and overwritten.
Do Not Edit! -->
<TITLE>$self->{_title}</TITLE>
<H1>$self->{_title}</H1>

<DL><p>
HTML

    return $header;
}

sub get_item_as_string
{
    my ($self, $item) = @_;

    if(!defined $item->{id} || !$self->{_items}{$item->{id}})
    {
        warn "No such item in get_item_as_string";
        return;
    }

    my $string = '';
    my ($url, $name, $visited, $created, $modified, $id, $icon, $charset, $panel) =
        ($item->{url} || '',
         $item->{name} || '',
         $item->{visited} || 0,
         $item->{created} || 0,
         $item->{modified} || 0,
         $item->{id} || 0,
         $item->{icon} || '',
         $item->{charset} || '',
         $item->{panel} || '');
    if($item->{type} eq 'folder')
    {
        $string .= << "HTML";
    <DT><H3 ADD_DATE="$created" LAST_MODIFIED="$modified" ID="$id">$name</H3>
    <DL><p>
HTML

        $string .= $self->get_item_as_string($self->{_items}{$_}) 
           foreach (@{$item->{children}});
        $string .= << "HTML";
    </DL><p>
HTML

    }
    elsif($item->{type} eq 'url')
    {
        $string .= << "HTML";
        <DT><A HREF="$url" ADD_DATE="$created" LAST_VISIT="$visited" ICON="$icon" LAST_CHARSET="$charset">$name</A>
HTML
    }

    return $string;
}

sub get_footer_as_string
{
    my ($self) = @_;

    my $footer = << "HTML";
</DL><p>
HTML

   return $footer;
}
1;
