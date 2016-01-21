require 'spec_helper'
require 'orientdb_client/instrumenters/memory'

RSpec.describe OrientdbClient do
  let(:client) { OrientdbClient.client }
  let(:username) { OrientdbClient::Test::Username }
  let(:valid_username) { OrientdbClient::Test::Username }
  let(:password) { OrientdbClient::Test::Password }
  let(:valid_password) { OrientdbClient::Test::Password }
  let(:db) { OrientdbClient::Test::DatabaseName }
  let(:temp_db_name) { "#{OrientdbClient::Test::DatabaseName}_temp" }

  describe 'integration specs', type: :integration do
    after(:each) do
      if client.connected?
        client.disconnect
      end
      if client.database_exists?(temp_db_name)
        client.delete_database(temp_db_name, username: valid_username, password: valid_password)
      end
    end

    describe '#connect' do
      subject { client.connect(username: username, password: password, db: db) }

      after(:each) do
        if client.connected?
          client.disconnect
        end
      end

      context 'with valid credentials' do
        let(:username) { OrientdbClient::Test::Username }
        let(:password) { OrientdbClient::Test::Password }
        let(:db) { OrientdbClient::Test::DatabaseName }

        it 'connects to the database' do
          subject
          expect(client.connected?).to be true
        end
      end

      context 'with invalid credentials' do
        let(:username) { 'foo' }
        let(:password) { 'bar' }
        let(:db) { OrientdbClient::Test::DatabaseName }

        it 'fails to connect' do
          begin
            subject
          rescue
          ensure
            expect(client.connected?).to be false
          end
        end

        it 'raises an UnauthorizedError' do
          expect { subject }.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#create_database' do
      before(:each) do
        if client.database_exists?(temp_db_name)
          client.delete_database(temp_db_name, username: username, password: password)
        end
      end

      context 'without existing connection' do
        context 'with valid authentication options' do
          it 'creates the database' do
            client.create_database(temp_db_name, 'plocal', 'document', username: username, password: password)
            expect(client.database_exists?(temp_db_name)).to be true
          end
        end

        context 'with invalid authentication options' do
          it 'raises UnauthorizedError' do
            expect do
              client.create_database(temp_db_name, 'plocal', 'document', username: 'foo', password: 'bar')
            end.to raise_exception(OrientdbClient::UnauthorizedError)
          end
        end
      end

      context 'with existing connection' do
        before do
          client.connect(username: username, password: password, db: db)
        end

        context 'with valid database parameters' do
          it 'creates a database' do
            client.create_database(temp_db_name, 'plocal', 'document')
            expect(client.database_exists?(temp_db_name)).to be true
          end
        end

        context 'with existing database' do
          it 'raises a ConflictError' do
            client.create_database(temp_db_name, 'plocal', 'document')
            expect(client.database_exists?(temp_db_name)).to be true
            expect do
              client.create_database(temp_db_name, 'plocal', 'document')
            end.to raise_exception(OrientdbClient::ConflictError)
          end

          it 'extracts the right conflict error message' do
            client.create_database(temp_db_name, 'plocal', 'document')
            expect(client.database_exists?(temp_db_name)).to be true
            begin
              client.create_database(temp_db_name, 'plocal', 'document')
            rescue => e
              expect(e.message).to eql('Database already exists')
            end
          end
        end

        context 'with invalid storage type' do
          it 'raises a ClientError' do
            expect do
              client.create_database(temp_db_name, 'foo', 'document')
            end.to raise_exception(OrientdbClient::ClientError, /OCommandExecutionException/)
          end
        end

        context 'with invalid database type' do
          it 'raises a ClientError' do
            expect do
              client.create_database(temp_db_name, 'memory', 'dog')
            end.to raise_exception(ArgumentError)
          end
        end
      end
    end

    describe '#delete_database' do
      if !$distributed_mode
        before(:each) do
          if !client.database_exists?(temp_db_name)
            client.create_database(temp_db_name, 'plocal', 'document', username: valid_username, password: valid_password)
          end
        end

        context 'without existing connection' do
          context 'with valid authentication options' do
            it 'deletes the database' do
              client.delete_database(temp_db_name, username: username, password: password)
              expect(client.database_exists?(temp_db_name)).to be false
            end
          end

          context 'with invalid authentication options' do
            it 'raises UnauthorizedError' do
              expect do
                client.delete_database(temp_db_name, username: 'foo', password: 'bar')
              end.to raise_exception(OrientdbClient::UnauthorizedError)
            end

            it 'does not delete the database' do
              begin
                client.delete_database(temp_db_name, username: 'foo', password: 'bar')
              rescue
              ensure
                expect(client.database_exists?(temp_db_name)).to be true
              end
            end
          end
        end

        context 'with existing connection' do
          before do
            client.connect(username: username, password: password, db: db)
          end

          context 'with valid database parameters' do
            it 'deletes the database' do
              client.delete_database(temp_db_name)
              expect(client.database_exists?(temp_db_name)).to be false
            end
          end

          context 'with no matching database' do
            it 'raises a ClientError' do
              expect do
                client.delete_database(temp_db_name + 'baz')
              end.to raise_exception(OrientdbClient::ClientError, /OConfigurationException/)
            end
          end
        end
      end
    end

    describe '#query' do
      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with valid query' do
          it 'returns result' do
            r = client.query('select * from OUser')
            expect(r).to be
          end
        end

        context 'with invalid query' do
          it 'raises ClientError' do
            expect { client.query('select * crumb') }.to raise_exception(OrientdbClient::ClientError, /OCommandSQLParsingException/)
          end
        end
        
        context 'with non-idempotent query' do
          it 'raises ClientError' do
            expect { client.query('create class User') }.to raise_exception(OrientdbClient::ClientError, /OCommandExecutionException/)
          end
        end
      end

      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect { client.query('select * from OUser') }.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#command' do
      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with valid command' do
          it 'returns result' do
            r = client.command('select * from OUser')
            expect(r).to be
          end
        end

        context 'with invalid JSON' do
          it 'raises SerializationException' do
            expect do
              client.command('insert into OUser CONTENT ' + Oj.dump({a:1}))
            end.to raise_exception(OrientdbClient::SerializationException)
          end
        end

        context 'creating index for property that does not exist' do
          it 'raises a ClientError' do
            expect do
              client.command('create index UserIdx on OUser (user_id) unique')
            end.to raise_exception(OrientdbClient::ClientError)
          end
        end

        context 'with invalid query' do
          it 'returns result' do
            expect { client.command('select * crumb') }.to raise_exception(OrientdbClient::ClientError, /OCommandSQLParsingException/)
          end
        end
      end

      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect { client.command('select * from OUser') }.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#get_class' do
      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with matching class' do
          it 'returns result' do
            r = client.get_class('OUser')
            expect(r).to be
          end
        end

        context 'with class that does not exist' do
          it 'raises NotFoundError' do
            expect { client.get_class('foobar') }.to raise_exception(OrientdbClient::NotFoundError)
          end
        end
      end

      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect { client.get_class('OUser') }.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#list_databases' do
      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with a database' do
          before(:each) do
            unless client.database_exists?(temp_db_name)
              client.create_database(temp_db_name, 'plocal', 'document', username: valid_username, password: valid_password)
            end
          end

          it 'returns an array including the database name' do
            expect(client.list_databases).to include(temp_db_name)
          end
        end
      end

      context 'when not connected' do
        it 'lists databases anyways' do
          expect { client.list_databases }.not_to raise_exception
        end
      end
    end

    describe '#create_property' do
      let(:class_name) { 'Member' }

      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'when class exists' do
          before do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
            client.create_class(class_name)
          end

          after do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
          end

          it 'can add string property to the class' do
            client.create_property(class_name, 'member_name', 'string')
            expect(client.get_class(class_name)['properties']).to include(hash_including({
              'name' => 'member_name',
              'type' => 'STRING',
              'mandatory' => false,
              'readonly' => false,
              'notNull' => false,
              'min' => nil,
              'max' => nil,
              'collate' => 'default'
            }))
          end

          it 'accepts options for the new property' do
            client.create_property(class_name, 'member_name', 'string', notnull: true, mandatory: true, min: 4, max: 10)
            expect(client.get_class(class_name)['properties']).to include(hash_including({
              'name' => 'member_name',
              'type' => 'STRING',
              'mandatory' => true,
              'readonly' => false,
              'notNull' => true,
              'min' => '4',
              'max' => '10',
              'collate' => 'default'
            }))
          end

          context 'when property already exists' do
            before do
              client.create_property(class_name, 'member_name', 'string')
            end

            it 'raises exception' do
              expect do
                client.create_property(class_name, 'member_name', 'string')
              end.to raise_exception(OrientdbClient::CommandExecutionException, /OCommandExecutionException/)
            end
          end
        end

        # This spec sometimes fails on Orientdb 2.1.X
        context 'when class does not exist' do
          it 'raises exception' do
            expect do
              client.create_property(class_name, 'member_name', 'string')
            end.to raise_exception(OrientdbClient::CommandExecutionException, /OCommandExecutionException/)
          end
        end
      end

      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect do
            client.create_property(class_name, 'member_name', 'string')
          end.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#alter_property' do
      let(:class_name) { 'Member' }

      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'when class and property exist' do
          before do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
            client.create_class(class_name) do |c|
              c.property('member_name', 'string')
            end
          end

          after do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
          end

          it 'can change string to be notnull' do
            client.alter_property(class_name, 'member_name', 'notnull', true)
            expect(client.get_class(class_name)['properties']).to include(hash_including({
              'name' => 'member_name',
              'type' => 'STRING',
              'mandatory' => false,
              'readonly' => false,
              'notNull' => true,
              'min' => nil,
              'max' => nil,
              'collate' => 'default'
            }))
          end
        end

        context 'when class does not exist' do
          before do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
          end

          it 'raises exception' do
            expect do
              client.create_property(class_name, 'member_name', 'string')
            end.to raise_exception(OrientdbClient::CommandExecutionException, /OCommandExecutionException/)
          end
        end

        context 'when class exists but property does not' do
          before do
            if (client.has_class?(class_name))
              client.drop_class(class_name)
            end
            client.create_class(class_name)
          end

          it 'raises exception' do
            expect do
              client.alter_property(class_name, 'member_name', 'notnull', true)
            end.to raise_exception(OrientdbClient::CommandExecutionException, /OCommandExecutionException/)
          end
        end
      end

      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect do
            client.create_property(class_name, 'member_name', 'string')
          end.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#create_class' do
      let(:class_name) { 'Member' }

      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)

          if (client.has_class?(class_name))
            client.drop_class(class_name)
          end
        end

        it 'creates the class' do
          expect(client.create_class(class_name)).to be
          expect(client.get_class(class_name)['name']).to eq(class_name)
        end

        it 'allows creation of classes that extend Vertex' do
          client.create_class(class_name, extends: 'V')
          expect(client.get_class(class_name)['superClass']).to eq('V')
        end

        it 'allows creation of abstract classes that extend Edge' do
          client.create_class(class_name, extends: 'E', abstract: true)
          expect(client.get_class(class_name)['superClass']).to eq('E')
          expect(client.get_class(class_name)['abstract']).to be true
        end

        it 'raises exception on creation of classes that extend nothing' do
          expect do
            client.create_class(class_name, extends: 'VJk')
          end.to raise_exception(OrientdbClient::ClientError, /OCommandSQLParsingException/)
        end

        describe 'with block' do
          it 'creates properties on the class' do
            client.create_class(class_name, extends: 'V') do |c|
              c.property('member_name', 'string', notnull: true)
            end
            expect(client.get_class(class_name)['properties']).to include(hash_including({
              'name' => 'member_name',
              'type' => 'STRING',
              'mandatory' => false,
              'readonly' => false,
              'notNull' => true,
              'min' => nil,
              'max' => nil,
              'collate' => 'default'
            }))
          end
        end

        context 'with existing class of that name' do
          it 'raises a ClientError' do
            client.create_class(class_name)
            expect do
              client.create_class(class_name)
            end.to raise_exception(OrientdbClient::ClientError, /OSchemaException/)
          end
        end
      end


      context 'when not connected' do
        it 'raises UnauthorizedError' do
          expect do
            client.create_class(class_name)
          end.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#drop_class' do
      let(:class_name) { 'Member' }

      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with class' do
          before(:each) do
            unless client.has_class?(class_name)
              client.create_class(class_name)
            end
          end

          it 'deletes the class' do
            client.drop_class(class_name)
            expect(client.has_class?(class_name)).to be false
          end
        end

        context 'without class' do
          before(:each) do
            if client.has_class?(class_name)
              client.drop_class(class_name)
            end
          end

          it 'returns nil' do
            expect(client.drop_class(class_name)).to be_nil
          end
        end
      end

      context 'without connection' do
        it 'raises UnauthorizedError' do
          expect { client.drop_class(class_name) }.to raise_exception(OrientdbClient::UnauthorizedError)
        end
      end
    end

    describe '#get_database' do
      context 'when connected' do
        before(:each) do
          client.connect(username: username, password: password, db: db)
        end

        context 'with db' do
          it 'returns the database' do
            expect(client.get_database(db)).to be
          end
        end

        context 'without db' do
          it 'raises NotFoundError' do
            expect { client.get_database('foo') }.to raise_exception(OrientdbClient::NotFoundError, /not authorized/)
          end
        end
      end

      context 'without connection' do
        it 'raises UnauthorizedError' do
          expect { client.get_database(db) }.to raise_exception(OrientdbClient::UnauthorizedError)
        end

        context 'with option auth data' do
          it 'returns the database' do
            expect(client.get_database(db, {username: username, password: password})).to be
          end
        end
      end
    end

    describe 'duplicate edge creation' do
      before do
        client.connect(username: username, password: password, db: db)
        if client.has_class?('Person')
          client.command('delete vertex Person')
          client.drop_class('Person')
        end
        if client.has_class?('Friend')
          client.drop_class('Friend')
        end
      end

      after do
        client.command('delete vertex Person')
        client.drop_class('Person')
        client.drop_class('Friend')
      end

      it 'raises DuplicateRecordError' do
        client.create_class('Person', extends: 'V')
        client.create_class('Friend', extends: 'E')
        client.command('create property Friend.out link Person')
        client.command('create property Friend.in link Person')
        client.command('create index FollowIdx on Friend (out,in) unique')
        client.command('create property Person.age integer')
        jim = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'jim'}))
        bob = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'bob'}))
        jim_rid = jim['result'][0]['@rid']
        bob_rid = bob['result'][0]['@rid']
        client.command("create edge Friend from #{jim_rid} to #{bob_rid}")
        expect do
          client.command("create edge Friend from #{jim_rid} to #{bob_rid}")
        end.to raise_exception(OrientdbClient::DuplicateRecordError, /found duplicated key/)
      end
    end

    describe 'handling `NegativeArraySizeException`s' do
      before do
        client.connect(username: username, password: password, db: db)
        if client.has_class?('Person')
          client.command('delete vertex Person')
          client.drop_class('Person')
        end
        if client.has_class?('Friend')
          client.drop_class('Friend')
        end
      end

      after do
        client.command('delete vertex Person')
        client.drop_class('Person')
        client.drop_class('Friend')
      end

      it 'translates this exception into a NotFoundError' do
        client.create_class('Person', extends: 'V')
        client.create_class('Friend', extends: 'E')
        client.command('create property Friend.out link Person')
        client.command('create property Friend.in link Person')
        client.command('create index FollowIdx on Friend (out,in) unique')
        client.command('create property Person.user_id integer')
        jim = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'jim', 'user_id' => 1}))
        bob = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'bob', 'user_id' => 2}))
        jim_rid = jim['result'][0]['@rid']
        bob_rid = bob['result'][0]['@rid']
        client.command("create edge Friend from #{jim_rid} to #{bob_rid}")
        expect do
          client.query("select in('Friend')[660-669].user_id,user_id from Person where user_id in [2]", {:limit=>1})
        end.to raise_exception(OrientdbClient::NotFoundError)
      end
    end

    describe 'duplicate record creation violating index constraint' do
      before do
        client.connect(username: username, password: password, db: db)
        if client.has_class?('Person')
          client.command('delete vertex Person')
          client.drop_class('Person')
        end
      end
      after do
        client.command('delete vertex Person')
        client.drop_class('Person')
      end

      it 'raises DuplicateRecordError' do
        error_klass = $distributed_mode ? OrientdbClient::DistributedDuplicateRecordError : OrientdbClient:: DuplicateRecordError
        client.create_class('Person', extends: 'V') do |c|
          c.property('user_id', 'integer')
        end
        client.command('create index PersonIdx on Person (user_id) unique')
        client.command('insert into Person CONTENT ' + Oj.dump({'user_id' => 1}))
        expect do
          client.command('insert into Person CONTENT ' + Oj.dump({'user_id' => 1}))
        end.to raise_exception(error_klass)
      end
    end

    describe 'instrumentation' do
      let(:memory_instrumenter) { OrientdbClient::Instrumenters::Memory.new }
      let(:client) { OrientdbClient.client(instrumenter: memory_instrumenter) }

      before do
        client.connect(username: username, password: password, db: db)
      end

      it 'instruments requests' do
        client.list_databases
        request_events = memory_instrumenter.events.select {|e| e.name == 'request.orientdb_client' }
        expect(request_events.size).to eq(2)

        connect_request_event = request_events.first
        expect(connect_request_event.payload[:url]).to match(/connect/)
        expect(connect_request_event.payload[:response_code]).to eq(204)

        list_event = request_events.last
        expect(list_event.payload[:url]).to match(/listDatabases/)
        expect(list_event.payload[:response_code]).to eq(200)
      end

      it 'works when the request fails' do
        allow(client.http_client).to receive(:request).and_call_original
        allow(client.http_client).to receive(:request).with(:get, "http://localhost:2480/class/orientdb_client_rb_test/OUser", anything) { raise 'err' }

        begin
          client.get_class('OUser')
        rescue
        ensure
          expect(memory_instrumenter.events.last.payload[:error]).to eq('RuntimeError')
        end
      end

      it 'instruments response handling' do
        client.list_databases
        response_events = memory_instrumenter.events.select {|e| e.name == 'process_response.orientdb_client' }
        expect(response_events.size).to eq(2)

        connect_response_event = response_events.first
        expect(connect_response_event.payload[:url]).to match(/connect/)
        expect(connect_response_event.payload[:response_code]).to eq(204)

        list_response_event = response_events.last
        expect(list_response_event.payload[:url]).to match(/listDatabases/)
        expect(list_response_event.payload[:response_code]).to eq(200)
      end

      it 'works when the response handling fails' do
        begin
          client.command('insert into OUser CONTENT ' + Oj.dump({a:1}))
        rescue
        ensure
          expect(memory_instrumenter.events.last.payload[:error]).to eq('OrientdbClient::SerializationException')
        end
      end
    end
  end

  # These specs will sometimes fail, not too much we can do about that, depends
  # on timing/threading in ruby and odb
  describe 'mvcc handling', type: :integration do
    let(:client) { OrientdbClient.client }
    before do
      client.connect(username: username, password: password, db: db)
      if client.has_class?('Person')
        client.command('delete vertex Person')
        client.drop_class('Person')
      end
      if client.has_class?('Friend')
        client.drop_class('Friend')
      end
    end

    after do
      client.command('delete vertex Person')
      client.drop_class('Person')
      client.drop_class('Friend')
    end

    it 'handles mvcc conflicts' do
      client.create_class('Person', extends: 'V')
      client.create_class('Friend', extends: 'E')
      client.command('create property Friend.out link Person')
      client.command('create property Friend.in link Person')
      client.command('create index FollowIdx on Friend (out,in) unique')
      client.command('create property Person.age integer')
      jim = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'jim'}))
      bob = client.command('insert into Person CONTENT ' + Oj.dump({'name' => 'bob'}))
      jim_rid = jim['result'][0]['@rid']
      bob_rid = bob['result'][0]['@rid']
      thrs = []
      err = nil
      begin
        thrs << Thread.new do
          100.times do
            client.command("create edge Friend from #{jim_rid} to #{bob_rid}")
            client.command("delete edge Friend from #{jim_rid} to #{bob_rid}")
          end
        end
        thrs << Thread.new do
          100.times do |i|
            client.command("update #{jim_rid} set age=#{i}")
            client.command("update #{bob_rid} set age=#{i}")
          end
        end
        thrs.each { |t| t.join }
      rescue => e
        err = e
      ensure
        if $distributed_mode
          correct_error_raised = err.is_a?(OrientdbClient::MVCCError) || err.is_a?(OrientdbClient::DistributedRecordLockedException)
        else
          correct_error_raised = err.is_a?(OrientdbClient::MVCCError)
        end
        expect(correct_error_raised).to be true
      end
    end
  end

  describe 'initialization' do
    context 'with non-default adapter' do
      it 'initializes specified adapter' do
        client = OrientdbClient.client(adapter: 'CurbAdapter')
        expect(client.http_client).to be_an_instance_of(OrientdbClient::HttpAdapters::CurbAdapter)
      end
    end
  end
end
