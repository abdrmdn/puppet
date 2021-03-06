require 'puppet/util/instance_loader'
require 'puppet/util/methodhelper'
require 'fileutils'

# Manage Reference Documentation.
class Puppet::Util::Reference
  include Puppet::Util
  include Puppet::Util::MethodHelper
  include Puppet::Util::Docs

  extend Puppet::Util::InstanceLoader

  instance_load(:reference, 'puppet/reference')

  def self.footer
    #TRANSLATORS message accompanied by date of generation
    "\n\n----------------\n\n*" + _("This page autogenerated on ") + "#{Time.now}*\n"
  end

  def self.modes
    %w{pdf text}
  end

  def self.newreference(name, options = {}, &block)
    ref = self.new(name, options, &block)
    instance_hash(:reference)[name.intern] = ref

    ref
  end

  def self.page(*sections)
    depth = 4
    # Use the minimum depth
    sections.each do |name|
      section = reference(name) or raise _("Could not find section %{name}") % { name: name }
      depth = section.depth if section.depth < depth
    end
  end

  def self.pdf(text)
    puts _("creating pdf")
    rst2latex = which('rst2latex') || which('rst2latex.py') ||
      raise(_("Could not find rst2latex"))

    cmd = %{#{rst2latex} /tmp/puppetdoc.txt > /tmp/puppetdoc.tex}
    Puppet::Util.replace_file("/tmp/puppetdoc.txt") {|f| f.puts text }
    # There used to be an attempt to use secure_open / replace_file to secure
    # the target, too, but that did nothing: the race was still here.  We can
    # get exactly the same benefit from running this effort:
    Puppet::FileSystem.unlink('/tmp/puppetdoc.tex') rescue nil
    output = %x{#{cmd}}
    unless $CHILD_STATUS == 0
      $stderr.puts _("rst2latex failed")
      $stderr.puts output
      exit(1)
    end
    $stderr.puts output

    # Now convert to pdf
    Dir.chdir("/tmp") do
      %x{texi2pdf puppetdoc.tex >/dev/null 2>/dev/null}
    end

  end

  def self.references
    instance_loader(:reference).loadall
    loaded_instances(:reference).sort { |a,b| a.to_s <=> b.to_s }
  end

  attr_accessor :page, :depth, :header, :title, :dynamic
  attr_writer :doc

  def doc
    if defined?(@doc)
      return "#{@name} - #{@doc}"
    else
      return @title
    end
  end

  def dynamic?
    self.dynamic
  end

  def initialize(name, options = {}, &block)
    @name = name
    set_options(options)

    meta_def(:generate, &block)

    # Now handle the defaults
    @title ||= _("%{name} Reference") % { name: @name.to_s.capitalize }
    @page ||= @title.gsub(/\s+/, '')
    @depth ||= 2
    @header ||= ""
  end

  # Indent every line in the chunk except those which begin with '..'.
  def indent(text, tab)
    text.gsub(/(^|\A)/, tab).gsub(/^ +\.\./, "..")
  end

  def option(name, value)
    ":#{name.to_s.capitalize}: #{value}\n"
  end

  def text
    puts output
  end

  def to_markdown(withcontents = true)
    # First the header
    text = markdown_header(@title, 1)
    #TRANSLATORS message accompanied by date of generation
    text << _("\n\n**This page is autogenerated; any changes will get overwritten** *(last generated on ") + "#{Time.now.to_s})*\n\n"

    text << @header

    text << generate

    text << self.class.footer if withcontents

    text
  end
end
