# encoding: UTF-8

require 'spec_helper'
require 'orientdb_client/integration/skylight_normalizer'

RSpec.describe Skylight::Normalizers::OrientdbClient::Query do

  let(:n) { Skylight::Normalizers::OrientdbClient::Query.new({}) }
  let(:name) { 'odb_query' }

  it 'normalizes a graph query' do
    name, title, desc = n.normalize(trace, name, url: 'http://localhost:2480/query/graphdb/sql/select+%2A+from+Post+order+by+%40rid+desc+limit+1')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: query')
    expect(desc).to be_nil
  end

  it 'normalizes a graph query without a title' do
    name, title, desc = n.normalize(trace, nil, url: 'http://localhost:2480/query/graphdb/sql/select+%2A+from+Post+order+by+%40rid+desc+limit+1')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: query')
    expect(desc).to be_nil
  end

  it 'normalizes a graph query with multibyte characaters' do
    name, title, desc = n.normalize(trace, nil, url: 'http://localhost:2480/query/graphdb/sql/select+%2A+from+Post+where+name+%3D+%22%F0%9D%92%9C+FROM+z%C3%B8mg+%C3%A5%22')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: query')
    expect(desc).to be_nil
  end

  it 'normalizes a graph update with JSON in URL' do
    name, title, desc = n.normalize(trace, name, url: 'http://localhost:2480/command/graphdb/sql/update+%2311%3A2+set+category_list%3D%5B%22sports%22%2C+%22gaming%22%2C+%22music%22%5D')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: command')
    expect(desc).to be_nil
  end

  it 'normalizes property creation commands' do
    name, title, desc = n.normalize(trace, name, url: 'http://localhost:2480/command/graphdb/sql/CREATE+PROPERTY+Post.id+string')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: command')
    expect(desc).to be_nil
  end

  it 'normalizes property alter commands' do
    name, title, desc = n.normalize(trace, name, url: 'http://localhost:2480/command/graphdb/sql/ALTER+PROPERTY+Post.exists+type+integer')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: command')
    expect(desc).to be_nil
  end

  it 'normalizes class creation commands' do
    name, title, desc = n.normalize(trace, name, url: 'http://localhost:2480/command/graphdb/sql/CREATE+CLASS+Post')
    expect(name).to eql('db.orientdb.query')
    expect(title).to eql('orientdb: command')
    expect(desc).to be_nil
  end

  it 'skips connect queries' do
    name, * = n.normalize(trace, name, url: 'http://localhost:2480/connect/graphdb')
    expect(name).to eql(:skip)
  end

  it 'skips disconnect queries' do
    name, * = n.normalize(trace, name, url: 'http://localhost:2480/disconnect')
    expect(name).to eql(:skip)
  end

  it 'skips listDatabase queries' do
    name, * = n.normalize(trace, name, url: 'http://localhost:2480/listDatabases')
    expect(name).to eql(:skip)
  end

  it 'skips database creation' do
    name, * = n.normalize(trace, name, url: 'http://localhost:2480/database/foobaz/plocal/graph')
    expect(name).to eql(:skip)
  end

  it 'skips unknown queries' do
    name, * = n.normalize(trace, name, url: 'http://localhost:2480/cluster/unknownop?x=y')
    expect(name).to eql(:skip)
  end
end
