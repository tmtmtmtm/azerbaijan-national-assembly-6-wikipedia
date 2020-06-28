#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

# the Wikipedia page only links a handful of the constituencies, so
# generate a lookup via a SPARQL query. Before running this scraper,
# run something like:
#   wd sparql constituencies.sparql > constituencies.json
class ConstituencyList
  require 'json'

  def initialize(pathname)
    @pathname = pathname
  end

  def find(id)
    mapping.fetch(id)
  end

  private

  attr_reader :pathname

  def json
    @json ||= ::JSON.parse(pathname.read, symbolize_names: true)
  end

  def mapping
    @mapping ||= json.map { |row| [ row[:item][:label][/(\d+)/, 1], row[:item][:value] ]}.to_h
  end
end


class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    member_items.map { |li| fragment(li => MemberItem).to_h }
  end

  private

  def member_items
    noko.xpath('.//h2[contains(.,"deputatlarının")]//following::table[1]//tr[td[a]]')
  end
end

class MemberItem < Scraped::HTML
  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :name do
    tds[0].css('a').map(&:text).map(&:tidy).first
  end

  field :areaLabel do
    tds[4].text[/(\d+)/, 1]
  end

  field :area do
    constituency_list.find(areaLabel)
  end

  field :partyLabel do
    tds[3].text.tidy
  end

  field :party do
    return 'Q327591' if partyLabel == 'Bitərəf'
    tds[3].css('a/@wikidata').map(&:text).first
  end

  private

  def tds
    noko.css('td')
  end

  def constituency_list
    @constituency_list ||= ConstituencyList.new(Pathname.new('constituencies.json'))
  end
end

url = 'https://az.wikipedia.org/wiki/Az%C9%99rbaycan_Milli_M%C9%99clisinin_VI_%C3%A7a%C4%9F%C4%B1r%C4%B1%C5%9F%C4%B1'
data = Scraped::Scraper.new(url => MembersPage).scraper.members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts (header + rows.join)
