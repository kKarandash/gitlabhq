# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../support/webmock'
require_relative '../../../scripts/pipeline/pre_merge_checks'

RSpec.describe PreMergeChecks, time_travel_to: Time.parse('2024-05-29T08:00:00 UTC'), feature_category: :tooling do
  include StubENV

  let(:instance)            { described_class.new }
  let(:project_id)          { '42' }
  let(:merge_request_iid)   { '1' }
  let(:current_pipeline_id) { mr_pipelines[0][:id].to_s }
  let(:mr_pipelines_url)    { "https://gitlab.test/api/v4/projects/#{project_id}/merge_requests/#{merge_request_iid}/pipelines" }

  let(:latest_mr_pipeline_ref) { "refs/merge-requests/1/merge" }
  let(:latest_mr_pipeline_created_at) { "2024-05-29T07:15:00 UTC" }
  let(:latest_mr_pipeline_name) { "Ruby 3.2 MR [tier:3, gdk]" }
  let(:latest_mr_pipeline_short) do
    {
      id: 1309901620,
      ref: latest_mr_pipeline_ref,
      status: "success",
      source: "merge_request_event",
      created_at: latest_mr_pipeline_created_at
    }
  end

  let(:latest_mr_pipeline_detailed) do
    latest_mr_pipeline_short.merge(name: latest_mr_pipeline_name)
  end

  let(:mr_pipelines) do
    [
      {
        id: 1309903341,
        ref: "refs/merge-requests/1/train",
        status: "success",
        source: "merge_request_event",
        created_at: "2024-05-29T07:30:00 UTC"
      },
      latest_mr_pipeline_short,
      {
        id: 1309753047,
        ref: "refs/merge-requests/1/train",
        status: "failed",
        source: "merge_request_event",
        created_at: "2024-05-29T06:30:00 UTC"
      },
      {
        id: 1308929843,
        ref: "refs/merge-requests/1/merge",
        status: "success",
        source: "merge_request_event",
        created_at: "2024-05-29T05:30:00 UTC"
      },
      {
        id: 1308699353,
        ref: "refs/merge-requests/1/head",
        status: "failed",
        source: "merge_request_event",
        created_at: "2024-05-29T04:30:00 UTC"
      }
    ]
  end

  before do
    stub_env(
      'CI_API_V4_URL' => 'https://gitlab.test/api/v4',
      'CI_PROJECT_ID' => project_id,
      'CI_MERGE_REQUEST_IID' => merge_request_iid,
      'CI_PIPELINE_ID' => current_pipeline_id
    )
  end

  describe '#initialize' do
    context 'when project_id is missing' do
      let(:project_id) { nil }

      it 'raises an error' do
        expect { instance }.to raise_error("Missing project_id")
      end
    end

    context 'when merge_request_iid is missing' do
      let(:merge_request_iid) { nil }

      it 'raises an error' do
        expect { instance }.to raise_error("Missing merge_request_iid")
      end
    end

    context 'when current_pipeline_id is missing' do
      let(:current_pipeline_id) { nil }

      it 'raises an error' do
        expect { instance }.to raise_error("Missing current_pipeline_id")
      end
    end
  end

  describe '#execute' do
    # rubocop:disable RSpec/VerifiedDoubles -- See the disclaimer above
    let(:api_client) { double('Gitlab::Client') }
    let(:latest_mr_pipeline) { double('pipeline', **latest_mr_pipeline_detailed) }

    # We need to take some precautions when using the `gitlab` gem in this project.
    #
    # See https://docs.gitlab.com/ee/development/pipelines/internals.html#using-the-gitlab-ruby-gem-in-the-canonical-project.
    #
    before do
      stub_request(:get, mr_pipelines_url).to_return(status: 200, body: mr_pipelines.to_json)

      allow(instance).to receive(:api_client).and_return(api_client)
      allow(api_client).to yield_pipelines(:merge_request_pipelines, mr_pipelines)

      # Ensure we don't output to stdout while running tests
      allow(instance).to receive(:puts)
    end

    def yield_pipelines(api_method, pipelines)
      messages = receive_message_chain(api_method, :auto_paginate)

      pipelines.inject(messages) do |stub, pipeline|
        stub.and_yield(double(**pipeline))
      end
    end
    # rubocop:enable RSpec/VerifiedDoubles

    context 'when default arguments are present' do
      context 'when we have a latest pipeline' do
        before do
          allow(api_client).to receive(:pipeline).with(project_id, mr_pipelines[1][:id]).and_return(latest_mr_pipeline)
        end

        context 'and it passes all the checks' do
          it 'does not raise an error' do
            expect { instance.execute }.not_to raise_error
          end
        end

        context 'and it is not a merged results pipeline' do
          let(:latest_mr_pipeline_ref) { "refs/merge-requests/1/head" }

          it 'raises an error' do
            expect { instance.execute }.to raise_error(
              "Expected to have a Merged Results pipeline but got #{latest_mr_pipeline_ref}!"
            )
          end
        end

        context 'and it is not fresh enough' do
          let(:latest_mr_pipeline_created_at) { "2024-05-29T03:30:00 UTC" }

          it 'raises an error' do
            expect { instance.execute }.to raise_error(
              "Expected latest pipeline to be created within the last 4 hours (it was created 4.5 hours ago)!"
            )
          end
        end

        context 'and it is a predictive pipeline' do
          let(:latest_mr_pipeline_name) { "Ruby 3.2 MR [predictive]" }

          it 'raises an error' do
            expect { instance.execute }
              .to raise_error(/\AExpected latest pipeline not to be a predictive pipeline!/)
          end
        end

        context 'and it is not a tier-3 pipeline' do
          let(:latest_mr_pipeline_name) { "Ruby 3.2 MR [tier:2]" }

          it 'raises an error' do
            expect { instance.execute }
              .to raise_error(/\AExpected latest pipeline to be a tier-3 pipeline!/)
          end
        end

        context 'and it is qa-only pipeline' do
          let(:latest_mr_pipeline_name) { "Ruby 3.2 MR [types:qa,qa-gdk]" }

          it 'does not raise an error' do
            expect { instance.execute }
              .not_to raise_error
          end
        end
      end

      context 'when we do not have a latest pipeline' do
        let(:mr_pipelines) do
          [
            {
              id: 1309903341,
              ref: "refs/merge-requests/1/train",
              status: "success",
              source: "merge_request_event",
              created_at: "2024-05-29T08:29:43.472Z"
            }
          ]
        end

        it 'raises an error' do
          expect { instance.execute }.to raise_error("Expected to have a latest pipeline but got none!")
        end
      end
    end
  end
end
