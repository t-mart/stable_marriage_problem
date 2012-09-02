module StableMarriage

  class PreferenceList
    attr_reader :list, :current_favorite_index

    private :current_favorite_index

    def initialize list
      @list = list
      @current_favorite_index = 0
    end

    def current_favorite
      @list[@current_favorite_index]
    end

    def next
      @current_favorite_index += 1
      raise RuntimeError if @current_favorite_index >= @list.length
      current_favorite
    end

    def preference_of person
      #return nil if person.nil?
      @list.each_with_index.find { |p,i| person == p}[1]
    end

    def to_s
      "#{@list.inject(Array.new){ |arr, partner| arr << [partner, arr.size] }.map{ |partner,i| (i == current_favorite_index ? "!" : "") + partner.name }}"
    end

    class << self
      #set the worst case lists for the pool
      #See Kapur, Krishnamoorthy in "Worst Case Choice for the Stable Marriage
      #Problem"
      def set_worst_case_pool_lists pool
        pool.men.each_with_index do |m,i|
          l = pool.women.dup
          n = l.slice!(l.size-1)
          l.rotate!(-1)
          l.rotate!(i)
          l << n
          m.pref_list = PreferenceList.new l
        end
        pool.women.each_with_index do |w,i|
          l = pool.men.dup
          if i <= pool.n_people - 3
            l = l.rotate!(i+2)
          elsif i == pool.n_people - 2
            l = l.rotate(1)
          end
          w.pref_list = PreferenceList.new l
        end
      end

      def set_randomized_pool_lists pool
        pool.men.each do |m|
          l = pool.women.dup
          l.shuffle!
          m.pref_list = PreferenceList.new l
        end
        pool.women.each do |w|
          l = pool.men.dup
          l.shuffle!
          w.pref_list = PreferenceList.new l
        end
      end

      #set preference lists s.t. there are an exponential number of stable
      #pairings
      #
      #See Thurber's "Concerning the maximum number of stable matchings
      #in the stable marriage problem", p 198
      #TODO: this isn't correct past n = 4, but admittedly, my algo is a hack
      #compared to the way thurber does it
      def set_exponential_stable_matchings_pool_lists pool
        raise RuntimeError if Math.log2(pool.men.size) != Math.log2(pool.men.size).to_i

        n = pool.men.size
        g = []
        n.times do |i|
          row = []
          n.times do |j|
            row << j
          end
          g << row
        end

        g.each_with_index do |row,i|
          if i % 2 == 0
            row.rotate! i
          else
            row.reverse!
            row.rotate! i + 1
          end
        end

        women_lists = []
        g.each do |row|
          women_lists << row.reverse
        end

        puts g.inspect
        puts women_lists.inspect

        set_custom_pool_lists pool, g, women_lists, true
      end

      #takes in 2 arrays of preference lists
      def set_custom_pool_lists pool, men_lists, women_lists, zero_index = true
        pool.men.each_with_index do |m,i|
          row = men_lists[i].map { |j| pool.women[j + (zero_index ? 0 : -1)] }
          m.pref_list = PreferenceList.new row
        end
        pool.women.each_with_index do |w,i|
          row = women_lists[i].map { |j| pool.men[j + (zero_index ? 0 : -1)] }
          w.pref_list = PreferenceList.new row
        end
      end
    end
  end

  class Person

    COMMON_MALE_NAMES = %w{James John Robert Michael William David Richard Charles Joseph Thomas}
    COMMON_FEMALE_NAMES = %w{Mary Patricia Linda Barbara Elizabeth Jennifer Maria Susan Margaret Dorothy}

    @@male_name_counter = 1
    @@female_name_counter = 1

    attr_accessor :engaged_to, :pref_list, :next_favorite_index
    attr_reader :name, :is_male

    def initialize is_male

      @is_male = is_male
      if is_male
        @name = COMMON_MALE_NAMES[@@male_name_counter % (COMMON_MALE_NAMES.length)] + "#{@@male_name_counter}"
        @@male_name_counter += 1
      else
        @name = COMMON_FEMALE_NAMES[@@female_name_counter % (COMMON_FEMALE_NAMES.length)] + "#{@@female_name_counter}"
        @@female_name_counter += 1
      end

      @engaged_to = nil

      #pref_list = PreferenceList.new
      @pref_list = nil #Persons themselves can't make a pref list until the pool has been made
    end

    def single?
      @engaged_to.nil?
    end

    def to_s
      "<Person: @name=#{@name}, @engaged_to=#{@engaged_to.nil? ? nil : @engaged_to.name}, @pref_list=#{@pref_list}>"
    end

    #the lower the distance, the more preferred the matching
    def pref_distance
      if @engaged_to.nil?
        nil
      else
        @pref_list.preference_of(@engaged_to)
      end
    end

    #returns the success of the engagement
    def propose! other
      if other.single?
        #first engagement for other
        @engaged_to = other
        other.engaged_to = self
        return true
      else
        current_pref = other.pref_list.preference_of(other.engaged_to)
        my_pref = other.pref_list.preference_of(self)
        #the lower the index, the more preferred
        if my_pref < current_pref
          #found better matching
          other.jilt!
          @engaged_to = other
          other.engaged_to = self
          return true
        else
          #reject this engagement
          return false
        end
      end
    end

    #drop a lover
    def jilt!
      raise RuntimeError if single?

      #jilt is being called by the engagees
      #so while we should increment the engagers next_favorite
      @engaged_to.pref_list.next
      @engaged_to.engaged_to = nil

      #we don't need to increment ours
      @engaged_to = nil
    end
  end

  class Pool

    attr_accessor :n_people, :men, :women

    def initialize n_people
      @n_people = n_people

      @men = n_people.times.to_a.map { Person.new(true) }
      @women = n_people.times.to_a.map { Person.new(false) }

    end

    def pp_engagements
      @men.each do |m|
        puts "#{m.name}(pd=#{m.pref_distance}) is engaged to #{m.engaged_to.nil? ? "--" : m.engaged_to.name + "(pd=#{m.engaged_to.pref_distance})"}"
      end
    end

    def men_pref_distance
      @men.map { |m| m.pref_distance }.inject(:+)
    end

    def women_pref_distance
      @women.map { |w| w.pref_distance }.inject(:+)
    end

    def has_rogue_couples?
      @men.each do |m|
        @women.each do |w|
          if (m.pref_list.preference_of(w) < m.pref_list.preference_of(m.engaged_to)) and (w.pref_list.preference_of(m) < w.pref_list.preference_of(w.engaged_to))
            return true
          end
        end
      end
      return false
    end

    def n_stable_matchings
      stable_matchings = 0
      test_pool = self.dup
      test_pool.women.permutation.each do |p|
        test_pool.men.each_with_index do |m, i|
          m.engaged_to = p[i]
          p[i].engaged_to = m
        end
        stable_matchings += 1 unless test_pool.has_rogue_couples?
      end
      stable_matchings
    end
  end

  class GaleShapely
    def initialize pool, men_optimal = true
      @pool = pool

      @proposers = men_optimal ? pool.men : pool.women

      @rounds = 0
    end

    def match! verbose = true

      until (single_proposers = @proposers.find_all { |p| p.single? }).empty?
        @rounds += 1
        if verbose
          puts "Round #{@rounds}"
          puts "============================"
        end

        single_proposers.each do |p|
          puts "#{p} is proposing to #{p.pref_list.current_favorite}"
          p.propose! p.pref_list.current_favorite
        end

        if verbose
          puts
          @pool.pp_engagements
        end
      end

      puts "Took #{@rounds} rounds."
      puts "There are #{@pool.has_rogue_couples? ? "" : "no "}rogue couples"
    end
  end
end

if __FILE__ == $0
  p = StableMarriage::Pool.new 4
  StableMarriage::PreferenceList.set_exponential_stable_matchings_pool_lists p
  puts p.n_stable_matchings
  #gs = StableMarriage::GaleShapely.new p
  #gs.match!

  #puts
  #puts "Men pd=#{p.men_pref_distance}"
  #puts "Women pd=#{p.women_pref_distance}"
end
