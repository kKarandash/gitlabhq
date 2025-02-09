<script>
import { escape, isEmpty } from 'lodash';
import ActionComponent from '~/ci/common/private/job_action_component.vue';
import { reportToSentry } from '~/ci/utils';
import RootGraphLayout from './root_graph_layout.vue';
import JobGroupDropdown from './job_group_dropdown.vue';
import JobItem from './job_item.vue';

export default {
  components: {
    ActionComponent,
    JobGroupDropdown,
    JobItem,
    RootGraphLayout,
  },
  props: {
    groups: {
      type: Array,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    pipelineId: {
      type: Number,
      required: true,
    },
    action: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    highlightedJobs: {
      type: Array,
      required: false,
      default: () => [],
    },
    isStageView: {
      type: Boolean,
      required: false,
      default: false,
    },
    jobHovered: {
      type: String,
      required: false,
      default: '',
    },
    pipelineExpanded: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    skipRetryModal: {
      type: Boolean,
      required: false,
      default: false,
    },
    sourceJobHovered: {
      type: String,
      required: false,
      default: '',
    },
    userPermissions: {
      type: Object,
      required: true,
    },
  },
  jobClasses: [
    'gl-p-3',
    'gl-border-0',
    'gl-rounded-base',
    'gl-hover-bg-gray-50',
    'gl-focus-bg-gray-50',
    'gl-hover-text-gray-900',
    'gl-focus-text-gray-900',
  ],
  computed: {
    canUpdatePipeline() {
      return this.userPermissions.updatePipeline;
    },
    columnSpacingClass() {
      return this.isStageView ? 'is-stage-view gl-m-5' : 'gl-my-5 gl-mx-7';
    },
    hasAction() {
      return !isEmpty(this.action);
    },
    showStageName() {
      return !this.isStageView;
    },
  },
  errorCaptured(err, _vm, info) {
    reportToSentry('stage_column_component', `error: ${err}, info: ${info}`);
  },
  mounted() {
    this.$emit('updateMeasurements');
  },
  methods: {
    getGroupId(group) {
      return group.name;
    },
    groupId(group) {
      return `ci-badge-${escape(group.name)}`;
    },
    isFadedOut(jobName) {
      return this.highlightedJobs.length > 1 && !this.highlightedJobs.includes(jobName);
    },
    isParallel(group) {
      return group.size > 1 && group.jobs.length > 1;
    },
    singleJobExists(group) {
      const firstJobDefined = Boolean(group.jobs?.[0]);

      if (!firstJobDefined) {
        reportToSentry('stage_column_component', 'undefined_job_hunt');
      }

      return group.size === 1 && firstJobDefined;
    },
  },
};
</script>
<template>
  <root-graph-layout
    :class="columnSpacingClass"
    class="stage-column gl-relative gl-flex-basis-full"
    data-testid="stage-column"
  >
    <template #stages>
      <div
        data-testid="stage-column-title"
        class="stage-column-title gl-display-flex gl-justify-content-space-between gl-relative gl-font-bold gl-pipeline-job-width gl-text-truncate gl-leading-36 gl-pl-4 -gl-mb-2"
      >
        <span :title="name" class="gl-text-truncate gl-pr-3 gl-w-17/20">
          {{ name }}
        </span>
        <action-component
          v-if="hasAction && canUpdatePipeline"
          :action-icon="action.icon"
          :tooltip-text="action.title"
          :link="action.path"
          class="js-stage-action"
          @pipelineActionRequestComplete="$emit('refreshPipelineGraph')"
        />
      </div>
    </template>
    <template #jobs>
      <div
        v-for="group in groups"
        :id="groupId(group)"
        :key="getGroupId(group)"
        data-testid="stage-column-group"
        class="gl-relative gl-white-space-normal gl-pipeline-job-width gl-mb-2"
        @mouseenter="$emit('jobHover', group.name)"
        @mouseleave="$emit('jobHover', '')"
      >
        <job-item
          v-if="singleJobExists(group)"
          :job="group.jobs[0]"
          :job-hovered="jobHovered"
          :skip-retry-modal="skipRetryModal"
          :source-job-hovered="sourceJobHovered"
          :pipeline-expanded="pipelineExpanded"
          :pipeline-id="pipelineId"
          :stage-name="showStageName ? group.stageName : ''"
          :css-class-job-name="$options.jobClasses"
          :class="[
            { 'gl-opacity-3': isFadedOut(group.name) },
            'gl-transition-duration-slow gl-transition-timing-function-ease',
          ]"
          @pipelineActionRequestComplete="$emit('refreshPipelineGraph')"
          @setSkipRetryModal="$emit('setSkipRetryModal')"
        />
        <div v-else-if="isParallel(group)" :class="{ 'gl-opacity-3': isFadedOut(group.name) }">
          <job-group-dropdown
            :group="group"
            :stage-name="showStageName ? group.stageName : ''"
            :pipeline-id="pipelineId"
            :css-class-job-name="$options.jobClasses"
          />
        </div>
      </div>
    </template>
  </root-graph-layout>
</template>
