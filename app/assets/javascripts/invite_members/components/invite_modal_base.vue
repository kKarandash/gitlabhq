<script>
import {
  GlCollapsibleListbox,
  GlFormGroup,
  GlModal,
  GlDatepicker,
  GlLink,
  GlSprintf,
  GlButton,
} from '@gitlab/ui';

import Tracking from '~/tracking';
import { sprintf } from '~/locale';
import ContentTransition from '~/vue_shared/components/content_transition.vue';
import { initialSelectedRole, roleDropdownItems } from 'ee_else_ce/members/utils';
import {
  ACCESS_LEVEL,
  ACCESS_EXPIRE_DATE,
  READ_MORE_TEXT,
  INVITE_BUTTON_TEXT,
  INVITE_BUTTON_TEXT_DISABLED,
  CANCEL_BUTTON_TEXT,
  HEADER_CLOSE_LABEL,
  ON_SHOW_TRACK_LABEL,
} from '../constants';

const DEFAULT_SLOT = 'default';
const DEFAULT_SLOTS = [
  {
    key: DEFAULT_SLOT,
    attributes: {
      class: 'invite-modal-content',
      'data-testid': 'invite-modal-initial-content',
    },
  },
];

export default {
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
    GlDatepicker,
    GlLink,
    GlModal,
    GlSprintf,
    GlButton,
    ContentTransition,
    ManageRolesDropdownFooter: () =>
      import('ee_component/members/components/action_dropdowns/manage_roles_dropdown_footer.vue'),
  },
  mixins: [Tracking.mixin()],
  inheritAttrs: false,
  props: {
    modalTitle: {
      type: String,
      required: true,
    },
    modalId: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    accessLevels: {
      type: Object,
      required: true,
    },
    defaultAccessLevel: {
      type: Number,
      required: true,
    },
    defaultMemberRoleId: {
      type: Number,
      required: false,
      default: null,
    },
    helpLink: {
      type: String,
      required: true,
    },
    labelIntroText: {
      type: String,
      required: true,
    },
    labelSearchField: {
      type: String,
      required: true,
    },
    formGroupDescription: {
      type: String,
      required: false,
      default: '',
    },
    submitDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoadingRoles: {
      type: Boolean,
      required: false,
      default: false,
    },
    invalidFeedbackMessage: {
      type: String,
      required: false,
      default: '',
    },
    submitButtonText: {
      type: String,
      required: false,
      default: INVITE_BUTTON_TEXT,
    },
    cancelButtonText: {
      type: String,
      required: false,
      default: CANCEL_BUTTON_TEXT,
    },
    currentSlot: {
      type: String,
      required: false,
      default: DEFAULT_SLOT,
    },
    extraSlots: {
      type: Array,
      required: false,
      default: () => [],
    },
    preventCancelDefault: {
      type: Boolean,
      required: false,
      default: false,
    },
    usersLimitDataset: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    // Be sure to check out reset!
    return {
      selectedAccessLevel: null,
      selectedDate: undefined,
      minDate: new Date(),
    };
  },
  computed: {
    accessLevelOptions() {
      return roleDropdownItems(this.accessLevels);
    },
    introText() {
      return sprintf(this.labelIntroText, { name: this.name });
    },
    exceptionState() {
      return this.invalidFeedbackMessage ? false : null;
    },
    selectId() {
      return `${this.modalId}_search`;
    },
    dropdownId() {
      return `${this.modalId}_dropdown`;
    },
    datepickerId() {
      return `${this.modalId}_expires_at`;
    },
    contentSlots() {
      return [...DEFAULT_SLOTS, ...(this.extraSlots || [])];
    },
    actionPrimary() {
      return {
        text: this.submitButtonText,
        attributes: {
          variant: 'confirm',
          disabled: this.submitDisabled,
          loading: this.isLoading,
        },
      };
    },
    actionCancel() {
      if (this.usersLimitDataset.closeToDashboardLimit && this.usersLimitDataset.userNamespace) {
        return {
          text: INVITE_BUTTON_TEXT_DISABLED,
          attributes: {
            href: this.usersLimitDataset.membersPath,
            category: 'secondary',
            variant: 'confirm',
          },
        };
      }

      return {
        text: this.cancelButtonText,
      };
    },
  },
  watch: {
    accessLevelOptions: {
      immediate: true,
      handler: 'resetSelectedAccessLevel',
    },
  },
  methods: {
    onReset() {
      // This component isn't necessarily disposed,
      // so we might need to reset it's state.
      this.resetSelectedAccessLevel();
      this.selectedDate = undefined;

      this.$emit('reset');
    },
    onShowModal() {
      this.$emit('shown');
      if (this.usersLimitDataset.reachedLimit) {
        this.track('render', { category: 'default', label: ON_SHOW_TRACK_LABEL });
      }
    },
    onCancel(e) {
      if (this.preventCancelDefault) {
        e.preventDefault();
      } else {
        this.onReset();
        this.$refs.modal.hide();
      }

      this.$emit('cancel');
    },
    onSubmit(e) {
      // We never want to hide when submitting
      e.preventDefault();

      const { accessLevel, memberRoleId } = this.accessLevelOptions.flatten.find(
        (item) => item.value === this.selectedAccessLevel,
      );
      this.$emit('submit', {
        accessLevel,
        memberRoleId,
        expiresAt: this.selectedDate,
      });
    },
    onClose() {
      this.$emit('close');
    },
    resetSelectedAccessLevel() {
      const accessLevel = {
        integerValue: this.defaultAccessLevel,
        memberRoleId: this.defaultMemberRoleId,
      };
      this.selectedAccessLevel = initialSelectedRole(this.accessLevelOptions.flatten, {
        accessLevel,
      });
    },
  },
  HEADER_CLOSE_LABEL,
  ACCESS_EXPIRE_DATE,
  ACCESS_LEVEL,
  READ_MORE_TEXT,
  INVITE_BUTTON_TEXT,
  CANCEL_BUTTON_TEXT,
  DEFAULT_SLOT,
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="modalId"
    data-testid="invite-modal"
    size="sm"
    dialog-class="gl-mx-5"
    :title="modalTitle"
    :header-close-label="$options.HEADER_CLOSE_LABEL"
    no-focus-on-show
    @shown="onShowModal"
    @close="onClose"
    @hidden="onReset"
  >
    <content-transition
      class="gl-display-grid"
      transition-name="invite-modal-transition"
      :slots="contentSlots"
      :current-slot="currentSlot"
    >
      <template #[$options.DEFAULT_SLOT]>
        <div class="gl-display-flex" data-testid="modal-base-intro-text">
          <slot name="intro-text-before"></slot>
          <p>
            <gl-sprintf :message="introText">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
            <slot name="intro-text-after"></slot>
          </p>
        </div>

        <slot name="alert"></slot>
        <slot name="active-trial-alert"></slot>

        <gl-form-group
          :label="labelSearchField"
          :label-for="selectId"
          :invalid-feedback="invalidFeedbackMessage"
          :state="exceptionState"
          :description="formGroupDescription"
          data-testid="members-form-group"
        >
          <slot name="select" v-bind="{ exceptionState, inputId: selectId }"></slot>
        </gl-form-group>

        <slot name="after-members-input"></slot>

        <gl-form-group
          class="gl-sm-w-half gl-w-full"
          :label="$options.ACCESS_LEVEL"
          :label-for="dropdownId"
        >
          <template #description>
            <gl-sprintf :message="$options.READ_MORE_TEXT">
              <template #link="{ content }">
                <gl-link :href="helpLink" target="_blank">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </template>
          <gl-collapsible-listbox
            :id="dropdownId"
            v-model="selectedAccessLevel"
            data-testid="access-level-dropdown"
            :items="accessLevelOptions.formatted"
            :loading="isLoadingRoles"
            block
          >
            <template #list-item="{ item }">
              <div :class="{ 'gl-font-weight-bold': item.memberRoleId }">{{ item.text }}</div>
              <div
                v-if="item.description"
                class="gl-text-gray-700 gl-font-sm gl-pt-1 gl-line-clamp-2 gl-whitespace-normal"
              >
                {{ item.description }}
              </div>
            </template>
            <template #footer>
              <manage-roles-dropdown-footer />
            </template>
          </gl-collapsible-listbox>
        </gl-form-group>

        <gl-form-group
          class="gl-sm-w-half gl-w-full"
          :label="$options.ACCESS_EXPIRE_DATE"
          :label-for="datepickerId"
        >
          <gl-datepicker
            v-model="selectedDate"
            :input-id="datepickerId"
            class="gl-display-block!"
            :min-date="minDate"
            :target="null"
          />
        </gl-form-group>
      </template>

      <template v-for="{ key } in extraSlots" #[key]>
        <slot :name="key"></slot>
      </template>
    </content-transition>

    <template #modal-footer>
      <div
        class="gl-m-0 gl-w-full gl-display-flex gl-flex-direction-column gl-sm-flex-direction-row-reverse"
      >
        <gl-button
          class="gl-w-full gl-sm-w-auto gl-sm-ml-3!"
          data-testid="invite-modal-submit"
          v-bind="actionPrimary.attributes"
          @click="onSubmit"
        >
          {{ actionPrimary.text }}
        </gl-button>

        <gl-button
          class="gl-w-full gl-sm-w-auto"
          data-testid="invite-modal-cancel"
          v-bind="actionCancel.attributes"
          @click="onCancel"
        >
          {{ actionCancel.text }}
        </gl-button>
      </div>
    </template>
  </gl-modal>
</template>
