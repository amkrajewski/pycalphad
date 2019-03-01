cimport cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free
import numpy as np
cimport numpy as np
from cpython cimport PyCapsule_CheckExact, PyCapsule_GetPointer
import pycalphad.variables as v

# From https://gist.github.com/pv/5437087
cdef void* cython_pointer(obj):
    if PyCapsule_CheckExact(obj):
        return PyCapsule_GetPointer(obj, NULL);
    raise ValueError("Not an object containing a void ptr")


cdef public class PhaseRecord(object)[type PhaseRecordType, object PhaseRecordObject]:
    """
    This object exposes a common API to the solver so it doesn't need to know about the differences
    between Model implementations. PhaseRecords are immutable after initialization.
    """
    def __reduce__(self):
            return PhaseRecord, (self.components, self.state_variables, self.variables, np.array(self.parameters),
                                 self._ofunc, self._gfunc, self._hfunc, self._massfuncs, self._massgradfuncs,
                                 self._masshessianfuncs, self._intconsfunc, self._intjacfunc, self._intconshessfunc,
                                 self._mpconsfunc, self._mpjacfunc, self._paramgradfunc, self._paramjacfunc,
                                 self.num_internal_cons, self.num_multiphase_cons)

    def __cinit__(self, object comps, object state_variables, object variables,
                  double[::1] parameters, object ofunc, object gfunc, object hfunc,
                  object massfuncs, object massgradfuncs, object masshessianfuncs,
                  object internal_cons_func, object internal_jac_func, object internal_cons_hess_func,
                  object multiphase_cons_func, object multiphase_jac_func, object parameter_grad_func,
                  object parameter_jac_func,
                  size_t num_internal_cons, size_t num_multiphase_cons):
        cdef:
            int var_idx, el_idx
        self.components = comps
        desired_active_pure_elements = [list(x.constituents.keys()) for x in self.components]
        desired_active_pure_elements = [el.upper() for constituents in desired_active_pure_elements for el in constituents]
        pure_elements = sorted(set(desired_active_pure_elements))
        nonvacant_elements = sorted([x for x in set(desired_active_pure_elements) if x != 'VA'])

        self.variables = variables
        self.state_variables = state_variables
        self.pure_elements = pure_elements
        self.nonvacant_elements = nonvacant_elements
        self.phase_dof = 0
        self.parameters = parameters
        self.num_internal_cons = num_internal_cons
        self.num_multiphase_cons = num_multiphase_cons

        for variable in variables:
            if not isinstance(variable, v.SiteFraction):
                continue
            self.phase_name = <unicode>variable.phase_name
            self.phase_dof += 1
        # Trigger lazy computation
        if ofunc is not None:
            self._ofunc = ofunc
            ofunc.kernel
            self._obj = <func_t*> cython_pointer(ofunc._cpointer)
        if gfunc is not None:
            self._gfunc = gfunc
            gfunc.kernel
            self._grad = <func_novec_t*> cython_pointer(gfunc._cpointer)
        if hfunc is not None:
            self._hfunc = hfunc
        self._hess = NULL
        if internal_cons_func is not None:
            self._intconsfunc = internal_cons_func
        self._internal_cons = NULL
        if internal_jac_func is not None:
            self._intjacfunc = internal_jac_func
        self._internal_jac = NULL
        if internal_cons_hess_func is not None:
            self._intconshessfunc = internal_cons_hess_func
        if multiphase_cons_func is not None:
            self._mpconsfunc = multiphase_cons_func
        self._multiphase_cons = NULL
        if multiphase_jac_func is not None:
            self._mpjacfunc = multiphase_jac_func
        self._multiphase_jac = NULL
        if parameter_grad_func is not None:
            self._paramgradfunc = parameter_grad_func
        self._parameter_grad = NULL
        if parameter_jac_func is not None:
            self._paramjacfunc = parameter_jac_func
        self._parameter_jac = NULL
        if massfuncs is not None:
            self._massfuncs = massfuncs
            self._masses = <func_t**>PyMem_Malloc(len(nonvacant_elements) * sizeof(func_t*))
            for el_idx in range(len(nonvacant_elements)):
                massfuncs[el_idx].kernel
                self._masses[el_idx] = <func_t*> cython_pointer(massfuncs[el_idx]._cpointer)
        if massgradfuncs is not None:
            self._massgradfuncs = massgradfuncs
            self._massgrads = <func_novec_t**>PyMem_Malloc(len(nonvacant_elements) * sizeof(func_novec_t*))
            for el_idx in range(len(nonvacant_elements)):
                massgradfuncs[el_idx].kernel
                self._massgrads[el_idx] = <func_novec_t*> cython_pointer(massgradfuncs[el_idx]._cpointer)
        if masshessianfuncs is not None:
            self._masshessianfuncs = masshessianfuncs
            self._masshessians = <func_novec_t**>PyMem_Malloc(len(nonvacant_elements) * sizeof(func_novec_t*))
            for el_idx in range(len(nonvacant_elements)):
                masshessianfuncs[el_idx].kernel
                self._masshessians[el_idx] = <func_novec_t*> cython_pointer(masshessianfuncs[el_idx]._cpointer)

    def __dealloc__(self):
        PyMem_Free(self._masses)
        PyMem_Free(self._massgrads)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void obj(self, double[::1] out, double[:,::1] dof) nogil:
        if self._obj != NULL:
            self._obj(&out[0], &dof[0,0], &self.parameters[0], <int>out.shape[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void grad(self, double[::1] out, double[::1] dof) nogil:
        if self._grad == NULL:
            with gil:
                self._gfunc.kernel
                self._grad = <func_novec_t*> cython_pointer(self._gfunc._cpointer)
        self._grad(&dof[0], &self.parameters[0], &out[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void hess(self, double[:, ::1] out, double[::1] dof) nogil:
        if self._hess == NULL:
            with gil:
                self._hfunc.kernel
                self._hess = <func_novec_t*> cython_pointer(self._hfunc._cpointer)
        self._hess(&dof[0], &self.parameters[0], &out[0,0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void internal_constraints(self, double[::1] out, double[::1] dof) nogil:
        if self._internal_cons == NULL:
            with gil:
                self._intconsfunc.kernel
                self._internal_cons = <func_novec_t*> cython_pointer(self._intconsfunc._cpointer)
        self._internal_cons(&dof[0], &self.parameters[0], &out[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void internal_jacobian(self, double[:, ::1] out, double[::1] dof) nogil:
        if self._internal_jac == NULL:
            with gil:
                self._intjacfunc.kernel
                self._internal_jac = <func_novec_t*> cython_pointer(self._intjacfunc._cpointer)
        self._internal_jac(&dof[0], &self.parameters[0], &out[0,0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void internal_cons_hessian(self, double[:, :, ::1] out, double[::1] dof) nogil:
        if self._internal_cons_hess == NULL:
            with gil:
                self._intconshessfunc.kernel
                self._internal_cons_hess = <func_novec_t*> cython_pointer(self._intconshessfunc._cpointer)
        self._internal_cons_hess(&dof[0], &self.parameters[0], &out[0,0,0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void multiphase_constraints(self, double[::1] out, double[::1] dof) nogil:
        if self._multiphase_cons == NULL:
            with gil:
                self._mpconsfunc.kernel
                self._multiphase_cons = <func_novec_t*> cython_pointer(self._mpconsfunc._cpointer)
        self._multiphase_cons(&dof[0], &self.parameters[0], &out[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void multiphase_jacobian(self, double[:, ::1] out, double[::1] dof) nogil:
        if self._multiphase_jac == NULL:
            with gil:
                self._mpjacfunc.kernel
                self._multiphase_jac = <func_novec_t*> cython_pointer(self._mpjacfunc._cpointer)
        self._multiphase_jac(&dof[0], &self.parameters[0], &out[0,0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void parameter_gradient(self, double[::1] out, double[::1] dof, double[::1] parameters) nogil:
        if self._parameter_grad == NULL:
            with gil:
                self._paramgradfunc.kernel
                self._parameter_grad = <func_novec_t*> cython_pointer(self._paramgradfunc._cpointer)
        self._parameter_grad(&dof[0], &parameters[0], &out[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void parameter_jacobian(self, double[:, ::1] out, double[::1] dof, double[::1] parameters) nogil:
        if self._parameter_jac == NULL:
            with gil:
                self._paramjacfunc.kernel
                self._parameter_jac = <func_novec_t*> cython_pointer(self._paramjacfunc._cpointer)
        self._parameter_jac(&dof[0], &parameters[0], &out[0,0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void mass_obj(self, double[::1] out, double[:, ::1] dof, int comp_idx) nogil:
        if self._masses != NULL:
            self._masses[comp_idx](&out[0], &dof[0,0], &self.parameters[0], <int>out.shape[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void mass_grad(self, double[::1] out, double[::1] dof, int comp_idx) nogil:
        if self._massgrads != NULL:
            self._massgrads[comp_idx](&dof[0], &self.parameters[0], &out[0])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void mass_hess(self, double[:,::1] out, double[::1] dof, int comp_idx) nogil:
        if self._masshessians != NULL:
            self._masshessians[comp_idx](&dof[0], &self.parameters[0], &out[0,0])
