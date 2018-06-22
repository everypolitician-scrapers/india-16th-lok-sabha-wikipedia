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

  private

  def tds
    noko.css('td,th')
  end
end

url = 'https://en.wikipedia.org/wiki/List_of_members_of_the_16th_Lok_Sabha'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[id])
