require 'thor'
require 'bio'

class FastaUtility < Thor
  include Thor::Actions
  Struct.new("Stats", :sum, :l50, :n50, :count, :mean, :median)
  
  no_tasks do
    def stats(lengths)
      lengths = lengths.sort{|a, b| b <=> a}
      stats = Struct::Stats.new
      
      temp_sum = 0
      stats[:sum] = lengths.inject(:+)
      stats[:l50] = lengths.find{|length| (temp_sum += length) > stats[:sum]/2.0}
      stats[:n50] = lengths.count{|length| length >= stats[:l50]}
      stats[:mean] = stats[:sum].to_f/lengths.length
      stats[:median] = (lengths.length % 2 == 0) ? (lengths[lengths.length/2-1] + lengths[lengths.length/2])/2.0 : lengths[lengths.length/2]
      stats[:count] = lengths.count
      return stats
    end
    
    def format(stats)
      output = []
      buffer_length = stats.members.map{|key| key.length}.max
      stats.each_pair do |key, value|
        numtype = value.is_a?(Float) ? "f" : "d"
        output << "  %-#{buffer_length}s: %#{numtype}" % [key.to_s.capitalize, value]
      end
      output.join("\n")
    end
  end
  
  desc "filecheck", "Checks to see if a given file exists. Used internally, don't worry about it too much", :hide => true
  def filecheck(filename)
    say "The file '#{filename}' doesn't seem to exist!", :red unless File.exists?(filename)
  end
  
  desc "lengths", "Print a set of summary statistics for the given fasta file, including L50, N50, sum and count."
  method_options [:cutoff, '-c'] => 0
  def lengths(filename)
    invoke :filecheck
    lengths =  Bio::FlatFile.open(filename).map{|entry| (entry.seq[-1,1] == "*") ? entry.length - 1 : entry.length}
    
    say "All entries", :green
    puts format(stats(lengths))
    if options.cutoff > 0
      say "Entries with length >= #{options.cutoff}", :green
      puts format(stats(lengths.find_all{|l| l >= options.cutoff}))
    end
  end
  
  desc "filter FILENAME [options]", "Impose a filter or set of filters on entries in a fasta file."
  long_desc "Impose a filter or set of filters on entries in a fasta file where each sequence in the file has to pass all of the filters to be printed."
  method_option :length_cutoff, :aliases => '-l', :type => :numeric, :default => 0,  :desc => 'Only entries with length >= cutoff will be returned.'
  method_option :inverse_match,  :aliases => '-v', :type => :boolean, :desc => "Return the inverse of the match after all the other filters have been applied."
  method_option :defline_grep,  :aliases => '-d', :type => :string,  :default => '', :desc => "A regular expression, used to search the entry's definition line."
  def filter(filename)
    invoke :filecheck
    Bio::FlatFile.open(filename).each do |entry|
      passed = true
      passed &&= (entry.length >= options.length_cutoff)
      passed &&= (entry.definition.match(Regexp.new(options.defline_grep)))
      passed = !passed if options.inverse_match
      puts entry if passed
    end
  end
  
  desc "clean FILENAME [options]", "Clean up a fasta file"
  method_option :wrap_width, :aliases => '-w', :type => :numeric, :desc => 'Wrap the fasta to N columns'
  def clean(filename)
    invoke :filecheck
    Bio::FlatFile.open(filename).each do |entry|
      puts entry.to_biosequence.output(:fasta, :header => entry.definition, :width => options.wrap_width)
    end
  end
  
  
  desc "sort FILENAME [options]", "Sorts a fasta file according to criteria"
  def sort(filename)
    invoke :filecheck
    Bio::FlatFile.open(filename).to_a.sort{|a,b| b.length <=> a.length}.each do |entry|
      puts entry
    end
  end
end
