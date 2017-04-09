#!/usr/bin/env ruby
require 'rubygems'
require 'engtagger'
require 'nokogiri'
require 'httparty'
require 'json'
require 'set'


# for having two selections.
class Triple
  attr_accessor :one, :two, :three
  def set(param, data)
    case param
      when 0
        @one = data
      when 1
        @two = data
      when 2
        @three = data
    end

  end
end

# for making random set
def rand_n(n, max)
  randoms = Set.new
  loop do
    randoms << rand(max)
    return randoms.to_a if randoms.size >= n
  end
end


# Create a parser object
class WordNode
	def initialize(tg,wd,li,wi)
		@tag = tg
		@word = wd
		@line = li
		@wordIndex = wi
	end
	def tag
		@tag
	end
	def wd
		@word
	end
	def li
		@line
	end
	def wi
		@wordIndex
	end
end


class Candidate
	def initialize(cand, li, wi)
		@candidate = cand
		@lineIndex = li
		@wordIndex = wi
	end
	def cd
		@candidate
	end
	def li
		@lineIndex
	end
	def wi
		@wordIndex
	end
end


class WordAPI
  def initialize
		# uri for verb conjugation
    @@c_origin = "http://api.ultralingua.com/api"
    @@api_key = "273ac3536af7a7075481145554dcb92d"
		# uri for adjective
		@@a_origin = "http://api.datamuse.com/words"
	end

	def verbConjugation(verb)
		uri = @@c_origin + '/conjugations' +'/eng/' + verb
		response = HTTParty.get(uri)
		JSON.parse(response.body)

	end
	def advToAdj(adv)
		uri = @@c_origin + '/stems' +'/eng/' + adv
    puts(uri)
		response = HTTParty.get(uri)
		jsonHash = JSON.parse(response.body)
    result = String.new
		jsonHash.each do |hash|
			if hash["partofspeech"]["partofspeechcategory"] == "adverb"
        if adv != hash["root"]
          result = hash["root"]
        end
      else
        return ""
			end
    end
    return result

	end
	def antAdj(adj)
		uri = @@a_origin + '?rel_ant=' + adj
		response = HTTParty.get(uri)
		jsonHash = JSON.parse(response.body)
		if jsonHash.size != 0
			return jsonHash[0]["word"]
		else
			return ""
		end
	end
end

class ProblemMaker
	def initialize
		@@tgr = EngTagger.new
		@@word_api = WordAPI.new
    @problemList = Array.new
  end
  def getInput
    @plainText
  end
	def input(text)
		@plainText = text
		# add tag to each word.
		tagged = @@tgr.add_tags(text)
		taggedArray = tagged.split

		# convert one dimension info to two dimension. 
		@tagged2DArray = Array.new
		@tagCountList = Hash.new
		lineIndex = 0
		wordIndex = 0
		taggedArray.each do |word|
			tagl = word.index('<')
			tagr = word.index('>')
			tag = word[tagl + 1, tagr - tagl - 1]
			nextTagl = word.rindex('<')
			wd = word[tagr + 1, nextTagl - tagr - 1]
			wNode = WordNode.new(tag, wd, lineIndex, wordIndex)
		
			# storing tag to 2D Array
      if @tagged2DArray[lineIndex] == nil
        @tagged2DArray[lineIndex] = Array.new
      end
			@tagged2DArray[lineIndex] << wNode

			# storing tag num.
			if @tagCountList[tag] == nil
				@tagCountList[tag] = Array.new
			end
      @tagCountList[tag] << wNode

			#if @tagCountList[tag]['count'] == nil
			#	@tagCountList[tag]['count'] = 1
			#	@tagCountList[tag]['words'] = Array.new
			#	@tagCountList[tag]['words'] << wNode
			#else
			#	@tagCountList[tag]['count'] = @tagCountList[tag]['count'] + 1
			#	@tagCountList[tag]['words'] << wNode
			#end

			wordIndex = wordIndex + 1

			if wd.index('.') != nil || wd.index('?') != nil || wd.index('!') != nil
				lineIndex = lineIndex + 1
        wordIndex = 0
			end

		end
	end
		# by using each tag Count, suggest the problem making case.
	def caseParsing
    if @plainText == nil
      puts "please first input your english text."
      return
    end
    @caseList = {
        "adv_to_adj" => Array.new,
        "ant_adj" => Array.new
    }

    @tagged2DArray.each do |line|
      line.each do |word|
        case word.tag
					when "rb"
						candWord = @@word_api.advToAdj(word.wd.to_s)

						if candWord != ""
							newCand = Candidate.new(candWord.to_s , word.li.to_i , word.wi.to_i)
							@caseList["adv_to_adj"] << newCand
						end
					when "jjr"
						# change to little, more, like that.
					when "jj"
						candWord = @@word_api.antAdj(word.wd.to_s)

						if candWord != ""
              puts word.wd.to_s + "to" + candWord
							newCand = Candidate.new(candWord.to_s, word.li.to_i, word.wi.to_i)
							@caseList["ant_adj"] << newCand
						end
					else
        end
			end
    end

    @caseList.each do |key, value|
      puts key + " Case has " + value.size.to_s + "candidates."
    end

	end
	
	def makeProblem
    @problemList = {
        "adv_to_adj" => Array.new,
        "ant_adj" => Array.new
    }

    @caseList["adv_to_adj"].each do |candidate|
      if @tagCountList['jj'].size > 5
        problem = String.new
        correctArr = Array.new
        li = candidate.li
        wi = candidate.wi
        candWord = @tagged2DArray[li][wi]
        correctArr << candWord

        randArr = rand_n(4, @tagCountList['jj'].size)
        randArr.each do |randIndex|
          correctArr << @tagCountList['jj'][randIndex]
        end
        randArr.shuffle

        candNum = 1
        correctNum = -1
        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              if word == candWord
                problem = problem + "[" + candNum.to_s + "]" + candidate.cd
                correctArr.delete(word)
                correctNum = candNum
              else
                problem = problem + "[" + candNum.to_s + "]" + word.wd
                correctArr.delete(word)
              end
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        problem = problem + "\ncorrect Number" + correctNum.to_s + " ,Answer is " + candWord.wd
        @problemList["adv_to_adj"] << problem
      end
    end
    # making antAdj Problem. It's size have to larger than 3
    if @caseList["ant_adj"].size >= 3
      # making combinations
      candCombList = @caseList["ant_adj"].combination(3).to_a
      candCombList.each do |candList|
        problem = String.new

        candArr = Array.new
        correctArr = Array.new

        tripleArr = Array.new


        candList.each do |candidate|
          li = candidate.li
          wi = candidate.wi
          correctArr << @tagged2DArray[li][wi]
          candArr << candidate.cd
        end

        correctTriple = Triple.new
        correctTriple.one = correctArr[0].wd
        correctTriple.two = correctArr[1].wd
        correctTriple.three = correctArr[2].wd
        tripleArr << correctTriple




        candNum = 0
        candCharArr =[ 'A', 'B', 'C']
        randOrderArr = Array.new

        @tagged2DArray.each do |line|
          line.each do |word|
            if correctArr.include?(word)
              randOrder = Random.rand(2)
              randOrderArr << randOrder
              if randOrder == 0
                problem = problem + "[" + candCharArr[candNum] + "]" + candArr[candNum] + "/" + correctArr[candNum].wd
              else
                problem = problem + "[" + candCharArr[candNum] + "]" + correctArr[candNum].wd + "/" + candArr[candNum]
              end
              candNum = candNum + 1
            else
              problem = problem + ' ' + word.wd
            end
          end
        end
        # candList 에서 하나 뽑고 correctList 에서 하나 뽑고 Triple로 만들어준다
        #000 010, 011, 110, 101

        while tripleArr.size != 5
          candTriple = Triple.new
          for i in 0..2
            randOrder = Random.rand(2)
            if randOrder == 0
              candTriple.set(i, candArr[i])
            else
              candTriple.set(i, correctArr[i].wd)
            end
          end
          notOverLap = true
          tripleArr.each do |triple|
            if (triple.one == candTriple.one) && (triple.two == candTriple.two) && (triple.three == candTriple.three)
              notOverLap = false
              break
            end
          end
          if notOverLap
            tripleArr << candTriple
          end
        end
        # triple sorting by ascending char order.
        #tripleArr.sort_by {|triple| triple.first}
        tripleArr.sort {|a,b| (a.one == b.one) ? a.two <=> b.two : a.one <=> b.one}


        problem = problem + "\n\t(A) \t (B) \t (C)\n"

        tripleNum = 0
        tripleArr.each do |triple|
          problem = problem + "[" + (tripleNum+1).to_s + "]"
          problem = problem + triple.one + "\t" + triple.two + "\t" + triple.three + "\n"
          tripleNum = tripleNum + 1
        end
        @problemList["ant_adj"] << problem
      end


    end
  end
  def printProblem(param)
    if @problemList[param].size == 0
      puts "there are no such " + param + "problem. sorry."
    end
    @problemList[param].each do |problem|
      puts problem
    end

  end
end
# Sample text
testtText = %q[Mathematics will attract those it can attract, but it will do nothing to overcome the resistance to science. Science is universal in principle but in practice it speaks to very few. Mathematics may be considered a communication skill of the highest type, frictionless so to speak; and at the opposite pole from mathematics, the fruits of science show the practical benefits of science without the use of words. But as we have seen, those fruits are ambivalent. Science as science does not speak; ideally, all scientific concepts are mathematized when scientists communicate with on e another, and when science displays its products to non-scientists it need not, and indeed is not able to, resort to salesmanship. When science speaks to others it is no longer science, and the scientist becomes or has to hire a publicist who dilutes the exactness of mathematics. In doing so the scientist reverses his drive toward mathematical exactness in favor of rhetorical vagueness and metaphor, thus violating the code of intellectual conduct that defines him as a scientist.]
=begin
pbr = ProblemMaker.new
pbr.input(testText)
pbr.caseParsing
pbr.makeProblem
=end

pbr = ProblemMaker.new
begin
  puts "What do you want to do? Choose your method"
  puts "1. input 2. caseParsing 3.makeProblem 4. printProblem X.Exit"
  input = gets.chomp
  case input
    when "1"
      puts "Please input your English text"
      testText = gets.chomp
      pbr.input(testText)
    when "2"
      pbr.caseParsing
    when "3"
      pbr.makeProblem
    when "4"
      puts "What do you want to category? 1)adv_to_adj 2) ant_adj"
      select = gets.chomp.to_i
      case select
        when 1
          category = "adv_to_adj"
        when 2
          category = "ant_adj"
      end
      pbr.printProblem(category)
    else
  end
end while input != "X"
puts "bye bye "

text = "Alice chased the big fat cat."
test = %q[ "'"""''''sd'''ruby test ]
text = %q[what are you talking about? I see what you]

tgr = EngTagger.new
# Add part-of-speech tags to text
tagged = tgr.add_tags(text)
print(tagged)
#=> "<nnp>Alice</nnp> <vbd>chased</vbd> <det>the</det> <jj>big</jj> <jj>fat</jj><nn>cat</nn> <pp>.</pp>"

# Get a list of all nouns and noun phrases with occurrence counts
word_list = tgr.get_words(text)

#=> {"Alice"=>1, "cat"=>1, "fat cat"=>1, "big fat cat"=>1}

# Get a readable version of the tagged text
readable = tgr.get_readable(text)

#=> "Alice/NNP chased/VBD the/DET big/JJ fat/JJ cat/NN ./PP"

# Get all nouns from a tagged output
nouns = tgr.get_nouns(tagged)

#=> {"cat"=>1, "Alice"=>1}

# Get all proper nouns
proper = tgr.get_proper_nouns(tagged)

#=> {"Alice"=>1}

# Get all past tense verbs
pt_verbs = tgr.get_past_tense_verbs(tagged)

#=> {"chased"=>1}

# Get all the adjectives
adj = tgr.get_adjectives(tagged)

#=> {"big"=>1, "fat"=>1}

# Get all noun phrases of any syntactic level
# (same as word_list but take a tagged input)
nps = tgr.get_noun_phrases(tagged)
print(nps)
#=> {"Alice"=>1, "cat"=>1, "fat cat"=>1, "big fat cat"=>1}
