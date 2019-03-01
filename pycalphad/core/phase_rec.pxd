ctypedef void func_t(double *out, double *dof, double *params, int bounds) nogil
ctypedef void func_novec_t(double *dof, double* params, double *out) nogil
cimport cython

@cython.final
cdef public class PhaseRecord(object)[type PhaseRecordType, object PhaseRecordObject]:
    cdef func_t* _obj
    cdef func_novec_t* _grad
    cdef func_novec_t* _hess
    cdef func_novec_t* _internal_cons
    cdef func_novec_t* _internal_jac
    cdef func_novec_t* _internal_cons_hess
    cdef func_novec_t* _multiphase_cons
    cdef func_novec_t* _multiphase_jac
    cdef func_t** _masses
    cdef func_novec_t** _massgrads
    cdef func_novec_t** _masshessians
    cdef func_novec_t* _parameter_grad
    cdef func_novec_t* _parameter_jac
    cdef public object _ofunc
    cdef public object _gfunc
    cdef public object _hfunc
    cdef public object _intconsfunc
    cdef public object _intjacfunc
    cdef public object _intconshessfunc
    cdef public object _mpconsfunc
    cdef public object _mpjacfunc
    cdef public size_t num_internal_cons
    cdef public size_t num_multiphase_cons
    cdef public object _massfuncs
    cdef public object _massgradfuncs
    cdef public object _masshessianfuncs
    cdef public object _paramgradfunc
    cdef public object _paramjacfunc
    cdef public object variables
    cdef public object state_variables
    cdef public object components
    cdef public object pure_elements
    cdef public object nonvacant_elements
    cdef public double[::1] parameters
    cdef public int phase_dof
    cdef public unicode phase_name
    cpdef void obj(self, double[::1] out, double[:,::1] dof) nogil
    cpdef void grad(self, double[::1] out, double[::1] dof) nogil
    cpdef void hess(self, double[:,::1] out, double[::1] dof) nogil
    cpdef void internal_constraints(self, double[::1] out, double[::1] dof) nogil
    cpdef void internal_jacobian(self, double[:,::1] out, double[::1] dof) nogil
    cpdef void internal_cons_hessian(self, double[:,:,::1] out, double[::1] dof) nogil
    cpdef void multiphase_constraints(self, double[::1] out, double[::1] dof_with_phasefrac) nogil
    cpdef void multiphase_jacobian(self, double[:,::1] out, double[::1] dof_with_phasefrac) nogil
    cpdef void mass_obj(self, double[::1] out, double[:, ::1] dof, int comp_idx) nogil
    cpdef void mass_grad(self, double[::1] out, double[::1] dof, int comp_idx) nogil
    cpdef void mass_hess(self, double[:,::1] out, double[::1] dof, int comp_idx) nogil
    cpdef void parameter_gradient(self, double[::1] out, double[::1] dof, double[::1] parameters) nogil
    cpdef void parameter_jacobian(self, double[:,::1] out, double[::1] dof, double[::1] parameters) nogil
