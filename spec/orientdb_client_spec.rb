require 'spec_helper'

RSpec.describe OrientdbClient do
  describe 'integration specs', type: :integration do
    let(:client) do
      c = OrientdbClient.client
      c.log_level = Logger::ERROR
      c
    end
    let(:username) { OrientdbClient::Test::Username }
    let(:valid_username) { OrientdbClient::Test::Username }
    let(:password) { OrientdbClient::Test::Password }
    let(:valid_password) { OrientdbClient::Test::Password }
    let(:db) { OrientdbClient::Test::DatabaseName }
    let(:temp_db_name) { "#{OrientdbClient::Test::DatabaseName}_temp" }

    after(:each) do
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
          it 'creates a database' do
            client.create_database(temp_db_name, 'plocal', 'document')
            expect(client.database_exists?(temp_db_name)).to be true
            expect do
              client.create_database(temp_db_name, 'plocal', 'document')
            end.to raise_exception(OrientdbClient::ConflictError)
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

        context 'with invalid query' do
          it 'returns result' do
            expect { client.query('select * crumb') }.to raise_exception(OrientdbClient::ClientError, /OCommandSQLParsingException/)
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

        context 'with invalid query' do
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

    describe '#create_class' do
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

          it 'creates the class' do
            expect(client.create_class(temp_db_name, 'Member')).to eq(9)
          end

          context 'with existing class of that name' do
            it 'raises a ClientError' do
              client.create_class(temp_db_name, 'Member')
              expect { client.create_class(temp_db_name, 'Member') }.to raise_exception(OrientdbClient::ClientError, /IllegalArgumentException/)
            end
          end
        end
      end

      context 'when not connected' do
        it 'lists databases anyways' do
          expect { client.list_databases }.not_to raise_exception
        end
      end
    end
  end
end
