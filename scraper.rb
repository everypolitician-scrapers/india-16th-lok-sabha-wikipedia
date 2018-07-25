#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def to_date
    return if empty?
    Date.parse(self).to_s rescue nil
  end
end

class MembersPage < Scraped::HTML
  decorator RemoveNotes
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :members do
    members_tables.xpath('.//tr[td]').map { |tr| fragment(tr => MemberRow) }.reject(&:vacant?).map(&:to_h)
  end

  private

  def members_tables
    noko.xpath('//table[.//th[contains(.,"Constituency")]]')
  end
end

class MemberRow < Scraped::HTML
  START_INDICATORS = %w[elected].to_set
  END_INDICATORS = %w[resigned died].to_set

  def vacant?
    tds[2].text == 'Vacant'
  end

  field :id do
    tds[2].css('a/@wikidata').map(&:text).first rescue binding.pry
  end

  field :name do
    tds[2].css('a').map(&:text).first unless vacant?
  end

  field :party_wikidata do
    tds[3].css('a/@wikidata').map(&:text).first
  end

  field :party do
    tds[3].text.tidy
  end

  field :constituency_wikidata do
    tds[1].css('a/@wikidata').map(&:text).first
  end

  field :constituency do
    tds[1].text.tidy
  end

  field :start_date do
    included_date[:when].to_date if START_INDICATORS.include? included_date[:what].to_s.downcase
  end

  field :end_date do
    included_date[:when].to_date if END_INDICATORS.include? included_date[:what].to_s.downcase
  end

  field :unexpected_date_type do
    ([included_date[:what].to_s.downcase] - START_INDICATORS.union(END_INDICATORS).to_a).join(', ')
  end

  private

  def tds
    noko.css('td,th')
  end

  def included_date
    tds[2].text.match(/\((?<what>.*) on (?<when>\d+ \w+ \d+)\)/) || {}
  end
end

url = 'https://en.wikipedia.org/wiki/List_of_members_of_the_16th_Lok_Sabha'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name party constituency])
